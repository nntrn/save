#!/usr/bin/env bash

# set -e
export GITHUB_TOKEN
TMPDIR=$(mktemp -d)

if [[ -n $GH_TOKEN ]]; then
  GITHUB_TOKEN=$GH_TOKEN
fi

_log() { echo -e "\033[0;${2:-33}m$1\033[0m" 3>&2 2>&1 >&3 3>&-; }
_completed() { _log "Completed: $*" 32; }
_error() { _log "Error: $*" 31; }
_info() { _log "Info: $*" 36; }

cleanup() {
  RC=$?
  if [[ $RC -eq 0 ]]; then
    rm -rf $TMPDIR
    [[ -d _data~ ]] && rm -rf _data~
    _completed "Cleaning up"
  else
    _error "Did not clean up old directories"
  fi
}

ghcurl() {
  local URL="${1:-"https://api.github.com/repos/nntrn/save/issues?per_page=100&state=open"}"
  curl -L -s -o ${2:-/dev/stdout} -H "Authorization: Bearer $GITHUB_TOKEN" "$URL" --fail
  [[ $? -ne 0 ]] && return 1
}

download_all_issues() {
  ghcurl "https://api.github.com/repos/nntrn/save/issues?per_page=100&state=open" |
    jq 'map(select(.author_association == "OWNER")|del(.reactions,.user)|.number |= tostring)'
}

# args <count> <id> <url>
download_comment() {
  if [[ $1 -gt 0 ]]; then
    _log "Fetching comments for $2"
    mkdir -p _data/comments
    ghcurl "${3}?per_page=100" |
      jq 'map(select(.author_association == "OWNER") | 
          . + {number: (.issue_url|split("/")|last)}|del(.user,.reactions)
        )' >_data/comments/${2}.json
  fi
}

build_all() {
  _log "Running build_all"
  [[ -d _data ]] && rm -rf _data

  mkdir -p _data/comments
  download_all_issues >_data/issues.json

  jq -r '.[]|[.comments,.number,.comments_url]|join(" ")' _data/issues.json |
    awk '$1 > 0' >$TMPDIR/comments.txt

  while read comments number comments_url; do
    download_comment $comments $number $comments_url
  done <$TMPDIR/comments.txt
}

download_artifacts() {
  _log "Running download_artifacts"
  ARTIFACTS_FILE=artifacts.json
  ghcurl "https://api.github.com/repos/nntrn/save/actions/artifacts" >$ARTIFACTS_FILE

  LAST_ARCHIVE_DATA_URL="$(
    jq -r '(.artifacts|sort_by(.created_at)
      | map(select(.name == "page_data" and (.expired|not)).archive_download_url)
      | last)? // ""' $ARTIFACTS_FILE
  )"

  if [[ -n $LAST_ARCHIVE_DATA_URL ]]; then
    _info "Downloading $LAST_ARCHIVE_DATA_URL"
    ghcurl "$LAST_ARCHIVE_DATA_URL" $TMPDIR/page_data.zip
    [[ -d _data ]] && mv _data _data~
    unzip -d _data $TMPDIR/page_data.zip
  else
    _info "No available artifacts... Building all"
    build_all
  fi
}

download_issue() {
  [[ ! -d _data ]] && download_artifacts
  _log "Running download_issue"

  export ISSUE_NUM=$1
  mkdir -p _data/comments
  download_all_issues >_data/issues.json

  c=($(jq -r '.[]|[.comments,.number,.comments_url]|join(" ")' _data/issues.json))
  download_comment "${c[@]}"
}

noop() {
  set
}

# trap cleanup EXIT
run_command="noop"

if [[ -n $1 ]]; then
  case $1 in
  workflow*) run_command="build_all" ;;
  push) run_command="download_artifacts" ;;
  issue*) run_command="download_issue $2" ;;
  build) run_command="build_all" ;;
  esac

  $run_command

fi
