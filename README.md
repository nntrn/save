# things i save on my phone

Create and update [blog] post using a project's [issues]! This project uses 
the magic that is Github Actions and Github Pages/Jekyll to create and
update a personal website from the Github app on your mobile phone!  

I use this project as a dumping ground for my thoughts and ideas and things to remember.

## build your own

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

Setting to create page content from [json] using [datapage.rb]:

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