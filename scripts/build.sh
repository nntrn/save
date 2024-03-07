#!/usr/bin/env bash

SCRIPT=$(realpath $0)
DIR=${SCRIPT%/*}

GITHUB_REPO=nntrn/save
ISSUES_URL="https://api.github.com/repos/$GITHUB_REPO/issues?per_page=100"
CACHE_DIR=$HOME/.cache/savedocs
OUTDIR=${1:-_issues}

mkdir -p $CACHE_DIR

_curl() {
  CHKSUM=$(echo "$*" | md5sum | awk '{print $1}')
  CACHEFILE=$CACHE_DIR/$CHKSUM
  if [[ ! -f $CACHEFILE ]]; then
    curl --create-dirs -o $CACHEFILE -H "Authorization: Bearer $GITHUB_TOKEN" "$@"
  fi
  cat $CACHEFILE
}

if [[ -n $GITHUB_TOKEN ]]; then

  _OUTDIR=$(realpath $OUTDIR)
  mkdir -p $OUTDIR

  eval "$(_curl "$ISSUES_URL" | jq --arg outdir $_OUTDIR -L $DIR -r 'include "blog"; 
    map(@sh "echo \(.|markdown_tmpl)" + " >\($outdir)/\(.number).md")|join("\n")')"

  while read LINE; do
    echo "$LINE"
    FILE_ID=$(echo "$LINE" | awk -F'/' '{print $8}')
    FILEPATH=$_OUTDIR/$FILE_ID.md
    _curl $LINE | jq -r 'map(select(.author_association == "OWNER")|"\n"+.body+"\n")|join("\n")' >>$FILEPATH
  done < <(_curl "$ISSUES_URL" | jq -r 'map(select(.comments > 0)|.comments_url)|join("\n")')

else
  echo "GITHUB_TOKEN not set"
fi
