#!/usr/bin/env bash

set -e
export ISSUESFILE=$1
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

jq_filter() {
  jq -cr 'map(select(.author_association == "OWNER"))|map(.number |= tostring| del(.reactions,.user)|@base64)[]'
}

build_all() {
  mkdir -p _data/{body,comments}
  BODYFILE=$TMPDIR/input.json
  DUMPFILE=$TMPDIR/dump.json

  jq -cr 'map(select(.author_association == "OWNER"))|map(.number |= tostring| del(.reactions,.user)|@base64)[]' ${1:-ISSUESFILE} >$BODYFILE

  _log "Creating body"
  while read LINE; do
    echo "$LINE" | base64 -d | jq >$DUMPFILE
    NEWNAME="_data/body/$(jq -r '.number' $DUMPFILE).json"
    cp $DUMPFILE $NEWNAME
  done <$BODYFILE

  _log "Creating comments"
  COMMENTS=($(jq '.[]|select(.comments > 0)|.number' ${1:-ISSUESFILE}))
  for issue_id in "${COMMENTS[@]}"; do
    TMPISSUEID="$TMPDIR/issue-${issue_id}.json"
    ghcurl "https://api.github.com/repos/nntrn/save/issues/$issue_id/comments?per_page=100" "$TMPISSUEID"

    jq 'map(select(.author_association == "OWNER"))
    | map(.number |= tostring| del(.reactions,.user))' $TMPISSUEID >_data/comments/$issue_id.json
  done
  mkdir -p assets
  zip -r assets/site.zip _data
}

if [[ ! -f $ISSUESFILE ]]; then
  ISSUESFILE=$TMPDIR/issues.json
  ghcurl "https://api.github.com/repos/nntrn/save/issues?per_page=100" $ISSUESFILE
fi

build_all $ISSUESFILE