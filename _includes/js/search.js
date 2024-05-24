const FETCH_URL = "{{ '/assets/data/posts.json' | relative_url }}"
const searchInput = $("#search-input")
const searchResults = $("#search-results")

function escapeHtml(s) {
  var ENTITY_MAP = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
    "/": "&#x2F;"
  }
  return ("" + s).replace(/[&<>"'/]/g, function (s) {
    return ENTITY_MAP[s]
  })
}

function cleanResultText(body, search) {
  const searchRE = new RegExp(`(${search})`, "i")
  const text = body
    .split(/[\n\r]{1,2}/g)
    .filter((e) => searchRE.test(e))
    .join("\n")

  const el = document.createElement("div")
  el.innerHTML = marked.parse(text)

  return Array.from(el.children)
    .map((e) => e.textContent.trim())
    .join(" ")
    .replace(searchRE, `<mark>$1</mark>`)
}

function populateSearchList() {
  const search = this.value
  const data = dataManager(FETCH_URL)
  const list = searchResults.querySelector("ul")
  if (search.length > 0) {
    searchResults.classList.remove("hidden")
    list.innerHTML = ""
    data
      .filter((e) => e.body.indexOf(search) > -1)
      .forEach((el) => {
        const item = document.createElement("li")
        item.innerHTML = [
          `<a href="{{ '' | relative_url }}/${el.number}">`,
          `<strong>${el.title}</strong>`,
          `<p>${cleanResultText(el.body, search)}</p>`, //
          "</a>"
        ].join("\n")
        list.appendChild(item)
      })
  } else {
    searchResults.classList.add("hidden")
  }
}
