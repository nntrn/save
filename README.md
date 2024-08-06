# things i save on my phone

Create and update [blog] post when [issues] are created/updated! 

This project uses the magic that is Github Actions and Jekyll so I can update [nntrn.github.io/save][blog] from my phone using the Github app.

## Build your own

Requires [jq] and [bundler]

```sh
# 0. Download jq and bundler if you don't have it already

# 1. Clone project
git clone https://github.com/nntrn/save.git
cd save

# 2. Set variables
export GITHUB_REPOSITORY=nntrn/save
export GITHUB_TOKEN=....

# 3. Fetch issues api to build posts
./scripts/build.sh _data

# 4. Serve
bundle install
bundle exec jekyll serve
```

### Generate output from json

With the plugin [datapage.rb], setting the variable `from_template`, in **_config.yml** 
will generate post and page content in `_site`.

```yml
# _config.yml

from_template:
  - data: "posts"       # takes _data/posts.json 
    template: "page"    # takes _layouts/page.html
    dir: "number"       # makes _site/8   
    index_files: true   # makes _site/8/index.html
```


### Notes

* Issues created by others will be ignored
* Closing an issue will also remove it from the blog
* Reopen issue to readd 


[blog]: https://nntrn.github.io/save/
[jq]: https://jqlang.github.io/jq/
[bundler]: https://bundler.io/
[issues]: https://github.com/nntrn/save/issues
[datapage.rb]: https://raw.githubusercontent.com/nntrn/save/main/_plugins/datapage.rb
[json]: https://nntrn.github.io/save/assets/data/posts.json