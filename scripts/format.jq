def capture_urls($str):
  "\n\($str)"
  | [capture("[\\s](?<url>http[^\\s\\)]+)"; "xg")?]
  | to_entries
  | map(select(.value.url|test("\\${{")|not)|[.key,.value.url])
;

def format_body($body;$urls):
  $body
  | reduce $urls[] as $x 
    (.; . |= gsub("(?<url>"+$x[1] + ")"; "["+ .url + "][\($x[0])]") ) 
  | [ ., "", ($urls|map("[\(.[0])]: \(.[1])") |join("\n")), ""]
  | join("\n")
;

def format:
  map(. + {body: ( 
    capture_urls(.body) as $a 
    | .body 
    | if ($a|length)>0 then format_body(.;$a) else (.//"") end
    )
  });
