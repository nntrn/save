#!/usr/bin/env bash

# set -e
export GITHUB_TOKEN
TMPDIR=$(mktemp -d)

if [[ -n $GH_TOKEN ]]; then
  GITHUB_TOKEN=$GH_TOKEN
fi

_log() { echo -e "\033[0;${2:-33}m$*\033[0m" 3>&2 2>&1 >&3 3>&-; }

ghcurl() {
  local URL="${1:-"https://api.github.com/repos/nntrn/save/issues?per_page=100"}"
  curl -L -s -o ${2:-/dev/stdout} -H "Authorization: Bearer $GITHUB_TOKEN" "$URL" --fail
  [[ $? -ne 0 ]] && exit 1
}

jq_filter() {
  jq 'map(select(.author_association == "OWNER"))|map(.number |= tostring| del(.reactions,.user))'
}

build_all() {
  _log "Running build_all"
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

download_artifacts() {
  _log "Running download_artifacts"
  ARTIFACTS_FILE=artifacts.json
  ghcurl "https://api.github.com/repos/nntrn/save/actions/artifacts" >$ARTIFACTS_FILE

  LAST_ARCHIVE_DATA_URL="$(
    jq -r '(.artifacts|sort_by(.created_at)|map(select(.name == "page_data" and (.expired|not)).archive_download_url)|last)? // ""' $ARTIFACTS_FILE
  )"

  if [[ -n $LAST_ARCHIVE_DATA_URL ]]; then
    _log "$LAST_ARCHIVE_DATA_URL"
    ZIPFILENAME=$TMPDIR/data-$RANDOM.zip
    curl -o $ZIPFILENAME -L -H "Authorization: Bearer $GITHUB_TOKEN" "$LAST_ARCHIVE_DATA_URL"
    unzip -n -d _data $ZIPFILENAME
  else
    build_all
  fi
}

download_single_issue() {
  local issueid=$1
  _log "Running download_single_issue $issueid"
  ISSUEFILE=_data/body/${issueid}.json
  COMMENTSFILE=_data/comments/${issueid}.json
  mkdir -p _data/{body,comments}

  ghcurl "https://api.github.com/repos/nntrn/save/issues/$issueid" | jq '.number |= tostring|del(.reactions,.user)' >$ISSUEFILE
  NUMCOMMENTS=$(jq -r '.comments' $ISSUEFILE)
  if [[ $NUMCOMMENTS -gt 0 ]]; then
    _log "Writing $COMMENTSFILE"
    ghcurl "https://api.github.com/repos/nntrn/save/issues/$issueid/comments?per_page=100" | jq_filter >$COMMENTSFILE
  fi
}

trap 'rm -rf "$TMPDIR"' EXIT

echo "$@"
run_command=""
if [[ -n $1 ]]; then
  echo "$1"
  case $1 in
  workflow_dispatch) run_command=build_all ;;
  push) run_command=download_artifacts ;;
  issues) run_command=download_artifacts ;;
  build) run_command=build_all ;;
  esac

  $run_command

  if [[ -n $2 ]]; then
    download_single_issue $2
  fi
fi
