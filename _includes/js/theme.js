function updateFavicon(h = 140, s = 70, l = 60) {
  const favicon = document.head.querySelector("[rel=icon]")
  const strokeColor = escape(`hsla(${h},${s}%,${l}%,.75)`)
  const fillColor = escape(`hsla(${h},${s}%,${l}%,.275)`)
  favicon.href = `data:image/svg+xml;utf8,<svg viewBox=".3 1.3 19.5 17.1" xmlns="http://www.w3.org/2000/svg" fill="red"><path fill="${fillColor}" stroke="${strokeColor}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" d="M1 6.13c0-1.16 0-1.97.08-2.57.08-.58.22-.86.42-1.06.2-.2.48-.34 1.06-.42C3.16 2 3.96 2 5.13 2h.42c1.06 0 1.38.01 1.66.13.28.12.52.34 1.27 1.08l.8.8.09.1c.61.6 1.06 1.06 1.64 1.3.59.24 1.22.24 2.1.24h1.75c1.17 0 1.97 0 2.58.08.58.08.86.22 1.06.42.2.2.34.48.42 1.06.08.6.08 1.4.08 2.57v3.65c0 1.17 0 1.97-.08 2.58-.08.58-.22.86-.42 1.06-.2.2-.48.34-1.06.41-.6.09-1.4.09-2.58.09H5.15c-1.17 0-1.97 0-2.58-.09-.58-.07-.86-.22-1.06-.41-.2-.2-.34-.48-.42-1.07C1 15.4 1 14.6 1 13.43v-7.3z"/></svg>`
}

function setTheme(h) {
  const hue = Number(h)
  $("#hue-selector").value = hue
  document.body.style.setProperty("--h", hue)
  updateFavicon(hue)
  localStorage.setItem("theme", hue)
}
