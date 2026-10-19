#!/usr/bin/env bash
set -euo pipefail

bucket=${1:?Usage: empty-versioned-preview-bucket.sh BUCKET PR_NUMBER}
pr_number=${2:?Usage: empty-versioned-preview-bucket.sh BUCKET PR_NUMBER}

if [[ ! "$pr_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "PR number must be a positive integer." >&2
  exit 1
fi

if [[ "$bucket" != "pr-${pr_number}-frontend-"* && "$bucket" != "deploy-aws-pr-${pr_number}-"* ]]; then
  echo "Refusing to empty bucket not associated with PR ${pr_number}: ${bucket}" >&2
  exit 1
fi

delete_request=$(mktemp)
trap 'rm -f "$delete_request"' EXIT

key_marker=""
version_id_marker=""

while true; do
  list_args=(
    s3api list-object-versions
    --bucket "$bucket"
    --max-keys 1000
    --no-paginate
    --output json
    --no-cli-pager
  )

  if [[ -n "$key_marker" ]]; then
    list_args+=(--key-marker "$key_marker")
  fi

  if [[ -n "$version_id_marker" ]]; then
    list_args+=(--version-id-marker "$version_id_marker")
  fi

  page=$(aws "${list_args[@]}")
  objects=$(jq -c '[((.Versions // []) + (.DeleteMarkers // []))[] | {Key, VersionId}]' <<<"$page")

  if [[ $(jq 'length' <<<"$objects") -gt 0 ]]; then
    jq -n --argjson objects "$objects" '{Objects: $objects, Quiet: true}' >"$delete_request"
    response=$(aws s3api delete-objects \
      --bucket "$bucket" \
      --delete "file://${delete_request}" \
      --output json \
      --no-cli-pager)

    errors=$(jq -c '.Errors // []' <<<"$response")
    if [[ "$errors" != "[]" ]]; then
      printf 'S3 returned errors while emptying s3://%s: %s\n' "$bucket" "$errors" >&2
      exit 1
    fi
  fi

  if [[ $(jq -r '.IsTruncated' <<<"$page") != "true" ]]; then
    break
  fi

  key_marker=$(jq -r '.NextKeyMarker // empty' <<<"$page")
  version_id_marker=$(jq -r '.NextVersionIdMarker // empty' <<<"$page")
  if [[ -z "$key_marker" ]]; then
    echo "S3 returned a truncated version listing without a next key marker." >&2
    exit 1
  fi
done

echo "Removed all object versions and delete markers from s3://${bucket}."