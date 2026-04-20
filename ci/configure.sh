#!/usr/bin/env bash
set -eu -o pipefail

FLY="${FLY_CLI:-fly}"
CONCOURSE_TARGET="${CONCOURSE_TARGET:-bosh}"

until "${FLY}" -t "${CONCOURSE_TARGET}" status; do
  "${FLY}" -t "${CONCOURSE_TARGET}" login
  sleep 1
done

rendered_template="$(ytt -f "$(dirname "${0}")")"

"${FLY}" -t "${CONCOURSE_TARGET}" set-pipeline \
  -p "bosh-apt-resources" \
  -c <(echo "${rendered_template}")
