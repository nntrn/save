#!/usr/bin/env bash

SCRIPT="$(realpath $0)"
DIR=${SCRIPT%/*/*}

JQ_EXPR_POSTS='
def format_search_body($str): 
  $str|gsub("\r";"")|split("\n")
  | map(
    select(test("```")|not)  
    | gsub("^[\\#]{1,5}\\s";"";"x") 
    | gsub("`";"")
    | gsub("\\*";"")
    |gsub("\\[(?<title>[^\\]]+)\\]\\(http[^\\)]+\\)";.title;"x")
    | select(test("[a-zA-Z0-9]"))  
  )
;

[$issues,$comments]
| flatten
| sort_by(.created_at)
| group_by(.number)
| map( # .[0] + 
  (map(.body)|join("\n\n")) as $body |
  { 
    number: .[0].number,
    title: .[0].title,
    html_url: .[0].html_url,
    created_at: min_by(.created_at).created_at,
    updated_at: max_by(.updated_at).updated_at,
    labels: .[0].labels,
    body: $body,
    search: format_search_body($body)
  }
)'

jq -n \
  --slurpfile issues $DIR/_data/issues.json \
  --slurpfile comments $DIR/_data/comments.json \
  "$JQ_EXPR_POSTS" |
  jq -L $DIR/scripts 'include "format"; format'
