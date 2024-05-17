#!/usr/bin/env bash

set -e

SCRIPT="$(realpath $0)"
DIR=${SCRIPT%/*/*}
SDIR=${SCRIPT%/*}
ISSUES_API_URL='https://api.github.com/repos/nntrn/save/issues?per_page=100&state=open'

JQ_CLEAN_EXPR='map(
  select(.author_association == "OWNER")
  | del(.reactions,.user)
  | . + {number:((.issue_url? // .url)|split("/")|last)}
  )'

JQ_COMMENTS_EXPR='.[]
  | select(.comments > 0)
  | [(.url|split("/")|last)+".json",.comments_url]
  | join(" ")'

LABEL_SUCCESS='\033[0;32m✔ \033[0m'
LABEL_ERROR='\033[0;31m✘ \033[0m'

_log() { echo -e "\033[0;${2:-37}m$1\033[0m" 3>&2 2>&1 >&3 3>&-; }
_exitMsg() { _log "$1" 31 && exit 1; }

check_file() { [[ -f $1 && -s $1 ]] && _log "$LABEL_SUCCESS $1" || _exitMsg "$LABEL_ERROR $1"; }

_chksum() {
  local YMD,CHKSUM
  YMD=$(date +%Y%m%d)
  CHKSUM=$(cksum <<<"$@")
  echo "${CHKSUM% *}.${YMD}"
}

_gh() {
  [[ -z $GITHUB_TOKEN ]] && _exitMsg "GITHUB_TOKEN is empty"
  _log "$1"
  curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "$1" --fail
  [[ $? -ne 0 ]] && _exitMsg "An error occured fetching"
}

_format_body() {
  cat | jq -L $SDIR 'include "format";format'
}

_main() {
  OUTDIR=$1
  [[ -d $OUTDIR/.comment ]] && rm -rf $OUTDIR/.comment
  mkdir -p $OUTDIR/.comment
  _gh "$ISSUES_API_URL" | jq "$JQ_CLEAN_EXPR" | _format_body >$OUTDIR/issues.json
  check_file $OUTDIR/issues.json
  while read _path _url; do
    _gh "$_url" | jq "$JQ_CLEAN_EXPR" >$OUTDIR/.comment/$_path
    check_file $OUTDIR/.comment/$_path
  done < <(jq -r "$JQ_COMMENTS_EXPR" $OUTDIR/issues.json)
  jq -s 'flatten' $OUTDIR/.comment/*.json | _format_body >$OUTDIR/comments.json
  check_file $OUTDIR/comments.json
  echo '*' >$OUTDIR/.gitignore
}

[[ -n $GH_TOKEN ]] &&
  GITHUB_TOKEN=$GH_TOKEN

# _log "Output: ${DIR/$PWD\//.}/_data"
_main ${1:-$DIR/_data}
