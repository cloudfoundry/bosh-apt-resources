#!/bin/bash

set -e
[ -n "$DEBUG" ] && set -x

# This script will generate a new /public.key and updates vault with the private key info
# To run locally:
#   REQUIREMENT: "git clone https://github.com/cloudfoundry/concourse-infra-for-fiwg in to your workspace/bosh directory"
#                "gcloud auth login" to the cloudfoundry gcp project
#   eval "$(~/workspace/bosh/concourse-infra-for-fiwg/bin/concourse-credhub-print-env)"
#   REPO_ROOT=$PWD scripts/generate-public-key.sh
#
# Tips on unattended GPG key generation: https://www.gnupg.org/documentation/manuals/gnupg/Unattended-GPG-key-generation.html
# Debian GPG key requirements: https://keyring.debian.org/creating-key.html

: ${REPO_ROOT:?required}
export KEY_AUTHOR=${KEY_AUTHOR:-"CloudFoundry Bot"}
export KEY_EMAIL=${KEY_EMAIL:-"bot@cloudfoundry.org"}

# change to the root of the repo
pushd ${REPO_ROOT}
mkdir -p tmp

export GNUPGHOME="$(mktemp -d)"
cat >$GNUPGHOME/gpg.conf <<EOF
personal-digest-preferences SHA256
cert-digest-algo SHA256
digest-algo SHA256
default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed
EOF

cat >tmp/bot <<EOF
    %no-protection
    %echo Generating a basic OpenPGP key
    Key-Type: RSA
    Key-Length: 4096
    Subkey-Type: ELG-E
    Subkey-Length: 4096
    Name-Real: ${KEY_AUTHOR}
    Name-Comment: Created by CI
    Name-Email: ${KEY_EMAIL}
    Expire-Date: 0
    # Do a commit here, so that we can later print "done" :-)
    %commit
    %echo done
EOF
gpg --batch --generate-key tmp/bot

gpg --list-keys

key_id=$(gpg --list-keys "${KEY_AUTHOR}" | grep "^      " | tail -n1 | awk '{print $1}')
echo "New key ID: $key_id"
echo ${key_id} > tmp/bot.id
gpg --export -a ${key_id} > public.key
gpg --export-secret-keys -a ${key_id} > tmp/bot.private.key
credhub set -n /concourse/main/bosh-apt-resources/gpg_private_key -t value -v "$(cat tmp/bot.private.key)"
credhub set -n /concourse/main/bosh-apt-resources/gpg_public_key -t value -v "$(cat public.key)"
credhub set -n /concourse/main/bosh-apt-resources/gpg_key_id -t value -v "${key_id}"

gpg --list-keys
gpg --fingerprint