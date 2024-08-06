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
