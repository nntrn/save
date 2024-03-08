#!/usr/bin/env bash

set -e
export GITHUB_TOKEN=$GH_TOKEN
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

_log() { echo -e "\033[0;${2:-33}m$*\033[0m" 3>&2 2>&1 >&3 3>&-; }

ghcurl() {
  local URL="${1:-"https://api.github.com/repos/nntrn/save/issues?per_page=100"}"
  _log "Fetching $URL"
  curl -o ${2:?} "$URL" -H "Authorization: Bearer $GITHUB_TOKEN" --fail
  if [[ $? -ne 0 ]]; then
    _log "An error occured. Aborting..." 31
    exit 1
  fi
}

download_artifacts() {
  _log "Running download_artifacts" 36
  ARTIFACTS_URL=https://api.github.com/repos/nntrn/save/actions/artifacts
  ghcurl "https://api.github.com/repos/nntrn/save/actions/artifacts" $TMPDIR/artifacts.json

  LAST_ARCHIVE_DATA_URL="$(
    curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "$ARTIFACTS_URL" |
      jq -r '.artifacts[]|select(.name == "page_data" and (.expired|not)).archive_download_url? // ""'
  )"

  if [[ -n $LAST_ARCHIVE_DATA_URL ]]; then
    curl -o data.zip -L -H "Authorization: Bearer $GITHUB_TOKEN" "$LAST_ARCHIVE_DATA_URL"
    unzip data.zip
    mkdir _data
    tar -xf artifact.tar -C _data
  else
    exit 1
  fi
}

build_all() {
  _log "Running build_all" 36
  ISSUESFILE=$TMPDIR/issues.json
  BODYFILE=$TMPDIR/input.json
  DUMPFILE=$TMPDIR/dump.json

  ghcurl "https://api.github.com/repos/nntrn/save/issues?per_page=100" $ISSUESFILE
  mkdir -p _data/{body,comments}

  _log "Creating body"
  jq -cr 'map(select(.author_association == "OWNER"))|map(.number |= tostring| del(.reactions,.user)|@base64)[]
  ' $ISSUESFILE >$BODYFILE
  while read LINE; do
    echo "$LINE" | base64 -d | jq >$DUMPFILE
    NEWNAME="_data/body/$(jq -r '.number' $DUMPFILE).json"
    cp $DUMPFILE $NEWNAME
  done <$BODYFILE

  _log "Creating comments"
  COMMENTS=($(jq '.[]|select(.comments > 0)|.number' $ISSUESFILE))
  for issue_id in "${COMMENTS[@]}"; do
    TMPISSUEID="$TMPDIR/issue-${issue_id}.json"
    ghcurl "https://api.github.com/repos/nntrn/save/issues/$issue_id/comments?per_page=100" "$TMPISSUEID"
    jq 'map(select(.author_association == "OWNER"))|map(.number |= tostring| del(.reactions,.user))
    ' $TMPISSUEID >_data/comments/$issue_id.json
  done
}

if [[ -n $1 ]]; then
  echo $1
  case $1 in
  workflow_dispatch)
    build_all
    ;;
  push)
    download_artifacts
    ;;
  issues)
    download_artifacts
    ;;
  esac
else
  exit 1
fi
