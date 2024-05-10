#!/usr/bin/env bash

set -e

SCRIPT="$(realpath $0)"
DIR=${SCRIPT%/*/*}
ISSUES_API_URL='https://api.github.com/repos/nntrn/save/issues?per_page=100&state=open'

[[ -n $GH_TOKEN ]] &&
  GITHUB_TOKEN=$GH_TOKEN

JQ_CLEAN_EXPR='map(
  select(.author_association == "OWNER")
  | del(.reactions,.user)
  | . + {number:((.issue_url? // .url)|split("/")|last)}
  )'

JQ_COMMENTS_EXPR='.[]
  | select(.comments > 0)
  | [(.url|split("/")|last)+".json",.comments_url]
  | join(" ")'

_log() { echo -e "\033[0;${2:-33}m$1\033[0m" 3>&2 2>&1 >&3 3>&-; }
_exitMsg() { _log "$1" 31 && exit 1; }

_hash() {
  local YMD,CHKSUM
  YMD=$(date +%Y%m%d)
  CHKSUM=$(cksum <<<'hello world')
  echo "${CHKSUM% *}.${YMD}"
}

_gh() {
  [[ -z $GITHUB_TOKEN ]] && _exitMsg "GITHUB_TOKEN is empty"
  curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "$1" --fail
  [[ $? -ne 0 ]] && _exitMsg "An error occured fetching"
}

_main() {
  OUTDIR=$1
  [[ -d $OUTDIR/.comment ]] && rm -rf $OUTDIR/.comment
  mkdir -p $OUTDIR/.comment
  _gh "$ISSUES_API_URL" | jq "$JQ_CLEAN_EXPR" >$OUTDIR/issues.json
  while read _path _url; do
    echo "$_url"
    _gh "$_url" | jq "$JQ_CLEAN_EXPR" >$OUTDIR/.comment/$_path
  done < <(jq -r "$JQ_COMMENTS_EXPR" $OUTDIR/issues.json)
  jq -s 'flatten' $OUTDIR/.comment/*.json >$OUTDIR/comments.json
  echo '*' >$OUTDIR/.gitignore
  echo "$OUTDIR"
}

_log "Output: $DIR/_data"

_main ${1:-$DIR/_data}
