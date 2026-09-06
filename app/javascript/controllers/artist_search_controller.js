import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "form"]
  static values  = { url: String }

  connect() {
    this.debounceTimer = null
    document.addEventListener("click", this.handleOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
  }

  handleOutsideClick = (event) => {
    if (!this.element.contains(event.target)) this.hide()
  }

  onInput() {
    const q = this.inputTarget.value.trim()
    clearTimeout(this.debounceTimer)

    if (q.length < 2) { this.hide(); return }

    // Spotify link: skip autocomplete, prompt to submit as-is.
    if (/open\.spotify\.com\/(intl-\w+\/)?artist\//.test(q)) {
      this.showState("Spotify-link herkend. Enter om toe te voegen.")
      return
    }

    this.showState("Zoeken…")
    this.debounceTimer = setTimeout(() => this.fetchResults(q), 200)
  }

  async fetchResults(q) {
    try {
      const res = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
        headers: { "Accept": "application/json" }
      })
      const data = await res.json().catch(() => ({}))
      if (data.error || !res.ok) {
        this.showState(`Spotify is tijdelijk niet bereikbaar${data.error ? ` (${data.error})` : ""}. Enter om alsnog toe te voegen.`)
        return
      }
      const results = data.results || []
      if (!results.length) {
        this.showState("Geen match gevonden. Enter om '" + this.inputTarget.value + "' handmatig toe te voegen.")
        return
      }
      this.render(results)
    } catch (e) {
      this.showState("Netwerkfout — enter om alsnog toe te voegen.")
    }
  }

  render(results) {
    this.resultsTarget.innerHTML = results.map(r => `
      <button type="button"
              data-action="click->artist-search#pick"
              data-name="${this.escape(r.name)}"
              class="w-full flex items-center gap-3 px-3 py-2 hover:bg-white/[0.06] text-left cursor-pointer">
        ${r.image_url
          ? `<img src="${r.image_url}" class="w-9 h-9 rounded-md object-cover shrink-0">`
          : `<div class="w-9 h-9 rounded-md bg-neutral-800 shrink-0"></div>`}
        <div class="min-w-0 flex-1">
          <div class="text-sm font-medium truncate">${this.escape(r.name)}</div>
          ${r.genres && r.genres.length
            ? `<div class="text-xs text-neutral-500 truncate">${r.genres.map(g => this.escape(g)).join(" · ")}</div>`
            : ""}
        </div>
      </button>
    `).join("")
    this.resultsTarget.classList.remove("hidden")
  }

  showState(text) {
    this.resultsTarget.innerHTML = `<div class="px-3 py-2 text-sm text-neutral-400">${this.escape(text)}</div>`
    this.resultsTarget.classList.remove("hidden")
  }

  pick(event) {
    const name = event.currentTarget.dataset.name
    this.inputTarget.value = name
    this.hide()
    this.formTarget.requestSubmit()
  }

  hide() {
    this.resultsTarget.classList.add("hidden")
    this.resultsTarget.innerHTML = ""
  }

  escape(str) {
    return String(str).replace(/[&<>"']/g, s => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[s]))
  }
}
