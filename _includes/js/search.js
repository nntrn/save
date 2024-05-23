const FETCH_URL = "{{ '/assets/data/posts.json' | relative_url }}"
const searchInput = $("#search-input")
const searchResults = $("#search-results")

function hash(key) {
  if (typeof key !== "string") {
    key = JSON.stringify(key)
  }
  let hashValue = 0
  const stringTypeKey = `${key}${typeof key}`

  for (let index = 0; index < stringTypeKey.length; index++) {
    const charCode = stringTypeKey.charCodeAt(index)
    hashValue += charCode << (index * 8)
  }

  return hashValue
}

function getLocalData(key) {
  return JSON.parse(localStorage.getItem(key))
}

function setStorage(key, data) {
  return localStorage.setItem(key, JSON.stringify(data))
}

function dataManager(localUrl) {
  const hashid = hash(localUrl)

  if (!localStorage.getItem(hashid)) {
    fetch(localUrl)
      .then((response) => response.json())
      .then((data) => setStorage(hashid, data))
  }

  return getLocalData(hashid)
}

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

function populateSearchList() {
  const search = this.value
  const data = dataManager(FETCH_URL)
  const list = searchResults.querySelector("ul")
  list.innerHTML = ""
  data
    .filter((e) => e.body.toLowerCase().indexOf(search) > -1)
    .forEach((el) => {
      const li = document.createElement("li")
      const content = el.body
        .split(/[\n\r]/g)
        .filter((e) => e.indexOf(search) > -1)
        .join("\n")
      li.innerHTML = [
        //
        `<a href="{{ '' | relative_url }}/${el.number}">`,
        `<strong>${el.title}</strong>`,
        `<p>${escapeHtml(content).replace(search, `<mark>${search}</mark>`)}</p>`,
        "</a>"
      ].join("\n")
      list.appendChild(li)
    })
}

window.addEventListener("load", function () {
  searchInput.addEventListener("keyup", populateSearchList)
})
