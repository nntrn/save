def squo: [39]|implode;

def squote($text): [squo,$text,squo]|join("");
def dquote($text): "\"\($text)\"";

def unsmart($text): $text | gsub("[“”]";"\"") | gsub("[’‘]";"'");
def unsmart: unsmart(.);

def jekyll_date_fmt($dt): $dt |fromdate|strflocaltime("%Y-%m-%d %H:%M:%S %z");

def jekyll_date_fmt: jekyll_date_fmt(.);

def get_author($a):
  (($a|split("(\\s)?[;&,]+";"x")|.[0]|gsub("[':]";"")|gsub("[\\.\\s]+";"-")|ascii_downcase)?);

def get_author: get_author(.);


def remove_citations($text):
  $text | gsub("(?<period>[a-zA-Z]\\.)[0-9]{1,2} ";.period+""; "xs");

def remove_citations: remove_citations(.);

def slugify($text):
  $text|tostring|ascii_downcase| split("[:&\\?\\.](\\s)?";"x")[0]
  | [[match("(?<a>[a-zA-Z0-9]+).*?";"ig")] | .[].string] | join("-");

def wrap_text($text):
  $text
  | gsub("[\\s]{2,}";" ";"x")
  | unsmart
  | split("\n")
  | map( gsub("\t";"") |
      gsub("[\\s]{2,}";" ";"x") |
      gsub("(?<a>[\\S][\\s\\S]{70,80}) "; .a + "\n"; "m") |
      splits("\n") |
      select(length > 1))
  | (.[0]|tostring|gsub("^[\\s]+";"")) as $first | .[1:] as $last
  | [ "*  \($first)", ($last|map("   \(.)")) ]
  | flatten(2)
  | join("\n")
;

def markdown_tmpl:
  [
    "---",
    "title: \"\(.title)\"",
    "date: \(.created_at|jekyll_date_fmt)",
    "modified: \(.updated_at|jekyll_date_fmt)",
    "id: \(.number)",
    "---",
    "",
    "",
   .body,
    ""
  ]
  | join ("\n");


def build:
  map( select(.author_association == "OWNER")
    | . + {
      slug: "\(.created_at|fromdate|strflocaltime("%Y-%m-%d"))-\(slugify(.title))",
      content: "\(markdown_tmpl)"
    }
  )
  | map(@sh "echo \( .content )" + " | cat -s > \(env.OUTDIR//"_posts")/\(.slug).md")
  ;
