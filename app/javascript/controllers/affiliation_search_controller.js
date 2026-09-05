import { Controller } from "@hotwired/stimulus"

// Autocomplete for the affiliation of a tournament registration.
// Picking a suggestion saves immediately; typing a new name reveals a save
// button that creates the affiliation.
export default class extends Controller {
  static targets = ["input", "results", "save"]
  static values = { searchUrl: String, current: String }

  connect() {
    this.hideResults()
    this.toggleSave()
  }

  search() {
    const query = (this.inputTarget.value || "").trim()
    this.toggleSave()

    if (query.length < 1) {
      this.hideResults()
      return
    }

    fetch(`${this.searchUrlValue}?q=${encodeURIComponent(query)}`, {
      headers: { Accept: "application/json" }
    })
      .then(response => response.json())
      .then(data => this.showResults(data))
      .catch(() => this.hideResults())
  }

  showResults(affiliations) {
    const current = (this.inputTarget.value || "").trim().toLowerCase()
    const suggestions = affiliations.filter(a => a.name.toLowerCase() !== current)

    if (suggestions.length === 0) {
      this.hideResults()
      return
    }

    this.resultsTarget.innerHTML = suggestions
      .map(a => `<div class="affiliation-option" data-action="click->affiliation-search#select" data-name="${this.escape(a.name)}">${this.escape(a.name)}</div>`)
      .join("")
    this.resultsTarget.style.display = ""
  }

  select(event) {
    this.inputTarget.value = event.currentTarget.dataset.name
    this.hideResults()
    this.submit()
  }

  submit() {
    this.element.requestSubmit ? this.element.requestSubmit() : this.element.submit()
  }

  // Hide the dropdown when focus moves away, leaving time for a click on it
  blur() {
    setTimeout(() => this.hideResults(), 150)
  }

  hideResults() {
    this.resultsTarget.innerHTML = ""
    this.resultsTarget.style.display = "none"
  }

  // The save button is only useful for a name that is not the saved one
  toggleSave() {
    if (!this.hasSaveTarget) return

    const value = (this.inputTarget.value || "").trim()
    const current = (this.currentValue || "").trim()
    this.saveTarget.style.display = value !== current ? "" : "none"
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
