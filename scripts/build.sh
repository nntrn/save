#!/usr/bin/env bash

# set -e

export GITHUB_TOKEN
export ISSUES_API_URL='https://api.github.com/repos/nntrn/save/issues?per_page=100&state=open'

GITHUB_TOKEN=${GITHUB_TOKEN:-$GH_TOKEN}

_log() { echo -e "\033[0;${2:-33}m$1\033[0m" 3>&2 2>&1 >&3 3>&-; }

ghcurl() {
  local URL="${1}"
  local OUTFILE="${2}"
  _log "$URL"
  curl -L -s --create-dirs -o $OUTFILE \
    -H "Authorization: Bearer $GITHUB_TOKEN" "$URL" --fail
  # [[ $? -ne 0 ]] && return 1
  # [[ -n $2 && ! -f $2 ]] && return 1
  # [[ -f $2 && ! -s $2 ]] && return 1
}

download_all_issues() {
  _len=100
  _page=0

  while test $_len -eq 100; do
    _page=$((_page + 1))
    _log $_page
    _out="$_tmp/issue-${_page}.json"

    ghcurl "${ISSUES_API_URL}&page=${_page}" "$_out"
    _len=$(jq -r 'length' $_out)
    _log "$_len"
  done
}

build_all() {
  mkdir -p _data
  download_all_issues

  cat $_tmp/issue*.json | jq -s 'flatten' |
    jq 'map(select(.author_association == "OWNER") | 
      del(.reactions,.user)|.number |= tostring)' >_data/issues.json

  jq -r '.[]|[.comments,.number,.comments_url]|join(" ")' _data/issues.json |
    awk '$1 > 0' >$_tmp/comments.txt

  while read c id comments_url; do
    ghcurl "$comments_url" "$_tmp/comments-${id}.json"
  done <$_tmp/comments.txt

  jq -s 'flatten | map(select(.author_association == "OWNER") |
    . + {number: (.issue_url|split("/")|last)}|del(.user,.reactions)
    )' .cache/comments*.json >_data/comments.json
}

_tmp=$(mktemp -d)
[[ -d _data ]] && rm -rf _data
build_all
