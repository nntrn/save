#!/usr/bin/env bash

# set -e
export GITHUB_TOKEN
TMPDIR=$(mktemp -d)

cleanup() {
  RC=$?
  if [[ $RC -eq 0 ]]; then
    rm -rf $TMPDIR
    [[ -d _data~ ]] && rm -rf _data~
  else
    echo "TMPDIR=$TMPDIR"
  fi
}

# trap cleanup INT TERM EXIT

# trap 'rm -rf "$TMPDIR"' EXIT

if [[ -n $GH_TOKEN ]]; then
  GITHUB_TOKEN=$GH_TOKEN
fi

_log() { echo -e "\033[0;${2:-33}m$*\033[0m" 3>&2 2>&1 >&3 3>&-; }

ghcurl() {
  local URL="${1:-"https://api.github.com/repos/nntrn/save/issues?per_page=100"}"
  curl -s -o ${2:-/dev/stdout} -H "Authorization: Bearer $GITHUB_TOKEN" "$URL" --fail
  [[ $? -ne 0 ]] && return 1
}

jq_filter() {
  jq 'map(select(.author_association == "OWNER"))|map(.number |= tostring| del(.reactions,.user))'
}

build_all() {
  _log "Running build_all"
  [[ -d _data ]] && mv _data _data~
  mkdir -p _data/comments
  ghcurl "https://api.github.com/repos/nntrn/save/issues?per_page=100" |
    jq 'map(select(.author_association == "OWNER")|del(.reactions,.user)|.number |= tostring)' >_data/issues.json

  _log "Creating comments"
  COMMENTS=($(jq -r 'map(select(.comments > 0)|.number)|join("\n")' _data/issues.json))
  for issue_id in "${COMMENTS[@]}"; do
    ghcurl "https://api.github.com/repos/nntrn/save/issues/$issue_id/comments?per_page=100" |
      jq 'map(select(.author_association == "OWNER")
      | . + {number: (.issue_url|split("/")|last)}
      | del(.reactions,.user))' >_data/comments/$issue_id.json
  done
}

download_artifacts() {
  _log "Running download_artifacts"
  ARTIFACTS_FILE=artifacts.json
  ghcurl "https://api.github.com/repos/nntrn/save/actions/artifacts" >$ARTIFACTS_FILE
  curl -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/nntrn/save/actions/artifacts" >$ARTIFACTS_FILE

  LAST_ARCHIVE_DATA_URL="$(
    jq -r '(.artifacts|sort_by(.created_at)|map(select(.name == "page_data" and (.expired|not)).archive_download_url)|last)? // ""' $ARTIFACTS_FILE
  )"

  if [[ -n $LAST_ARCHIVE_DATA_URL ]]; then
    _log "$LAST_ARCHIVE_DATA_URL"
    ZIPFILENAME=data.zip
    curl -o $ZIPFILENAME -L -H "Authorization: Bearer $GITHUB_TOKEN" "$LAST_ARCHIVE_DATA_URL"
    if [[ -d _data ]]; then
      ls -laptr _data
      mv _data _data~
    fi
    _log "Unzipping"
    unzip -d _data $ZIPFILENAME
  else
    cat $ARTIFACTS_FILE
    _log "Archive data null"
    build_all
  fi
}

download_single_issue() {
  issueid=$1
  _log "Running download_single_issue $issueid"
  ISSUEFILE=_data/body/${issueid}.json
  COMMENTSFILE=_data/comments/${issueid}.json
  mkdir -p _data/{body,comments}

  ghcurl "https://api.github.com/repos/nntrn/save/issues/${issueid}" $ISSUEFILE
  NUMCOMMENTS=$(jq -r '.comments' $ISSUEFILE)
  if [[ $NUMCOMMENTS -gt 0 ]]; then
    _log "Writing $COMMENTSFILE"
    ghcurl "https://api.github.com/repos/nntrn/save/issues/$issueid/comments?per_page=100" >$COMMENTSFILE
  fi
}

trap cleanup EXIT
run_command="build_all"

if [[ -n $1 ]]; then
  R=$1
  case $R in
  workflow_dispatch) run_command=build_all ;;
  push) run_command=download_artifacts ;;
  issues) run_command=download_artifacts ;;
  build) run_command=build_all ;;
  esac

  if [[ -n $2 ]]; then
    $run_command
    download_single_issue $2
  else
    $run_command
  fi
fi
