#!/usr/bin/env bash

SCRIPT="$(realpath "$0")"
DIR=${SCRIPT%/*/*}
DATADIR=$DIR/_data

export GITHUB_TOKEN

ISSUES_API_URL='https://api.github.com/repos/nntrn/save/issues?per_page=100&state=open'
JQ_CLEAN_EXPR='map(select(.author_association == "OWNER")|del(.reactions,.user)|.+{number:((.issue_url? // .url)|split("/")|last)})'
JQ_COMMENTS_EXPR='.[]|select(.comments > 0)|[(.url|split("/")|last)+".json",.comments_url]|join(" ")'

# export OUTDIR=${1:-$PWD/_data}

if [[ -n $GH_TOKEN ]]; then
  GITHUB_TOKEN=$GH_TOKEN
fi

_log() { echo -e "\033[0;${2:-33}m$1\033[0m" 3>&2 2>&1 >&3 3>&-; }

_gh() {
  curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "$1" --fail
}

_main() {
  OUTDIR="$(realpath $1)"

  [[ -d $OUTDIR ]] && rm -rf $OUTDIR

  mkdir -p $OUTDIR/.comment
  _gh "$ISSUES_API_URL" | jq "$JQ_CLEAN_EXPR" >$OUTDIR/issues.json

  while read _path _url; do
    echo "$_url"
    _gh "$_url" | jq "$JQ_CLEAN_EXPR" >$OUTDIR/.comment/$_path
  done < <(jq -r "$JQ_COMMENTS_EXPR" $OUTDIR/issues.json)

  jq -s 'flatten' $OUTDIR/.comment/*.json >$OUTDIR/comments.json
  echo "$OUTDIR"
}

_main ${1:-$DATADIR}
