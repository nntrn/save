#!/usr/bin/env bash

set -e
export GITHUB_TOKEN
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if [[ -z $GITHUB_TOKEN ]]; then
  GITHUB_TOKEN=$GH_TOKEN
fi

_log() { echo -e "\033[0;${2:-33}m$*\033[0m" 3>&2 2>&1 >&3 3>&-; }

ghcurl() {
  local URL="${1:-"https://api.github.com/repos/nntrn/save/issues?per_page=100"}"
  curl -s -o ${2:-/dev/stdout} "$URL" -H "Authorization: Bearer $GITHUB_TOKEN" --fail
  [[ $? -ne 0 ]] && exit 1
}

jq_filter() {
  jq 'map(select(.author_association == "OWNER"))|map(.number |= tostring| del(.reactions,.user))'
}

download_single_issue() {
  mkdir -p _data/{body,comments}
  local id=$1
  ISSUEFILE=_data/body/${id}.json
  COMMENTSFILE=_data/comments/${id}.json
  mkdir -p _data/{body,comments}

  ghcurl "https://api.github.com/repos/nntrn/save/issues/$id" | jq '.number |= tostring|del(.reactions,.user)' >$ISSUEFILE
  COMMENTS=$(jq -r '.comments' $ISSUEFILE)
  if [[ $COMMENTS -gt 0 ]]; then
    ghcurl "https://api.github.com/repos/nntrn/save/issues/$id/comments?per_page=100" | jq_filter >$COMMENTSFILE
  fi
}

download_artifacts() {
  _log "Running download_artifacts" 36

  LAST_ARCHIVE_DATA_URL="$(
    ghcurl "https://api.github.com/repos/nntrn/save/actions/artifacts" |
      jq -r '(.artifacts|sort_by(.created_at)
        |map(select(.name == "page_data" and (.expired|not)).archive_download_url)|last)? // ""'
  )"

  if [[ -n $LAST_ARCHIVE_DATA_URL ]]; then
    _log "$LAST_ARCHIVE_DATA_URL"
    curl -o $TMPDIR/data.zip -L -H "Authorization: Bearer $GITHUB_TOKEN" "$LAST_ARCHIVE_DATA_URL"
    unzip -d _data $TMPDIR/data.zip
  else
    echo "Aborting..."
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

export issue_id
echo "$@"
if [[ -n $1 ]]; then
  echo "$1"
  case $1 in
  workflow_dispatch) run_command=build_all ;;
  push) run_command=download_artifacts ;;
  issues) run_command=download_artifacts ;;
  build) run_command=build_all ;;
  esac

  echo "Running $run_command"
  $run_command

  if [[ -n $2 ]]; then
    download_single_issue $2
  fi
fi
