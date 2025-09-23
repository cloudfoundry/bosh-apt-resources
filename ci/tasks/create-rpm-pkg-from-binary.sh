#!/bin/bash

set -e
[ -n "$DEBUG" ] && set -x

#
# ci/tasks/create-debian-pkg-from-binary.sh - Create .deb package
#
# This script is run from a concourse pipeline (per ci/pipeline.yml).
#

echo ">> Retrieving version metadata"

VERSION=$(cat recipe/version)
if [[ -z "${VERSION:-}" ]]; then
  echo >&2 "VERSION not found in `recipe/version`"
  exit 1
fi
# strip any non numbers; https://github.com/stedolan/jq/releases tag is "jq-1.5"
VERSION=$(echo $VERSION | sed "s/^[a-z\-]*//")
# pivnet versions might look like 1.0.0#2018-02-15T14:57:14.495Z
VERSION=$(echo $VERSION | sed "s/#.*//")
# Allow VERSION to be used in IN_BINARY
IN_BINARY=$(eval echo "${IN_BINARY}")

if [ ! -z "$GEM_HOME" ]; then
  export PATH="$GEM_HOME/bin:$PATH"
fi

mkdir -p certs
echo "${GPG_ID:?required}" > certs/id
echo "${GPG_PUBLIC_KEY:?required}" > certs/public.key
set +x
echo "${GPG_PRIVATE_KEY:?required}" > certs/private.key
[ -n "$DEBUG" ] && set -x

echo ">> Setup GPG public key"
gpg --import certs/public.key
echo ">> Setup GPG private key"
gpg --allow-secret-key-import --import certs/private.key
echo ">> List keys"
gpg --list-secret-keys

echo ">> Creating rpm package"
if [[ ! -x fpm ]]; then
  gem install fpm --no-document
fi

mkdir ~/.aws
cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY:?required}
aws_secret_access_key = ${AWS_SECRET_KEY:?required}
EOF


apt install -y -q file

recipe_binaries=
provides=
for binary in $OUT_BINARY; do
  if [[ "recipe/${IN_BINARY}" != "recipe/${binary}" ]]; then
    if file -b recipe/${IN_BINARY} | grep -q "gzip compressed data"; then
      tar xfz recipe/${IN_BINARY} -C recipe
    else
      cp --remove-destination recipe/${IN_BINARY} recipe/${binary}
    fi
  fi
  chmod +x recipe/${binary}
  recipe_binaries="${recipe_binaries} recipe/${binary}=/usr/bin/${binary} "
  provides="${provides} --provides ${binary} "
done


echo ">> Creating RPM package dependencies"
apt -y -q update
# apt install -y -q rpm

# -----------------------------
# Build .rpm package
# -----------------------------
echo ">> Creating RPM package"
fpm -s dir -t rpm -n "${NAME:?required}" -v "${VERSION}" \
  --vendor "${VENDOR:-Unknown}" \
  --license "${LICENSE:-Unknown}" \
  -m "${MAINTAINERS:-Unknown}" \
  --description "${DESCRIPTION:-Unknown}" \
  --url "${URL:-Unknown}" \
  $provides \
  $recipe_binaries

RPM_FILE="${NAME}-${VERSION}.x86_64.rpm"

echo ">> Uploading RPM package to rpm repository"
if [[ ! -x rpm-s3 ]]; then
  gem install rpm-s3 --no-document
fi

rpm-s3 upload "${RPM_FILE}" \
  --bucket "${RPM_RELEASE_BUCKET}" \
  --s3-region us-east-1 \
  --sign "$(cat certs/id)"

echo ">> Latest rpm package list"
rpm-s3 list -b "${RPM_RELEASE_BUCKET}"