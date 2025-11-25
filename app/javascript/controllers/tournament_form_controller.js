import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tournament-form"
export default class extends Controller {
  static targets = ["format", "rounds", "locationBlock", "scoringWrapper", "scoringInfo"]
  static values = { scoringSystemsUrl: String }

  connect() {
    this.toggleRounds()
    this.toggleOnline()
    this.loadScoringSystems()
  }

  toggleRounds() {
    const value = this.formatTarget.value
    const show = value === "swiss"
    this.roundsTarget.style.display = show ? "block" : "none"
  }

  toggleOnline() {
    const form = this.element
    const onlineInput = form.querySelector('input[name="tournament[online]"]')
    const online = onlineInput && (onlineInput.checked || onlineInput.value === "1")
    if (this.hasLocationBlockTarget) {
      this.locationBlockTarget.style.display = online ? "none" : "block"
    }
  }

  async loadScoringSystems() {
    const form = this.element
    const systemSelect = form.querySelector('select[name="tournament[game_system_id]"]')
    if (!systemSelect) return
    const update = async () => {
      const systemId = systemSelect.value
      if (!systemId) {
        if (this.hasScoringWrapperTarget) this.scoringWrapperTarget.style.display = 'none'
        if (this.hasScoringInfoTarget) this.scoringInfoTarget.innerHTML = ''
        return
      }
      try {
        const url = `${this.scoringSystemsUrlValue}?game_system_id=${encodeURIComponent(systemId)}`
        const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
        if (!response.ok) throw new Error("Network error")
        const list = await response.json()
        this.populateScoring(list)
      } catch (_e) {
        this.populateScoring([])
      }
    }
    systemSelect.addEventListener('change', update)
    update()
  }

  populateScoring(list) {
    const select = this.element.querySelector('select[name="tournament[scoring_system_id]"]')
    if (!select) return
    if (!list || list.length === 0) {
      if (this.hasScoringWrapperTarget) this.scoringWrapperTarget.style.display = 'none'
      if (this.hasScoringInfoTarget) this.scoringInfoTarget.innerHTML = ''
      return
    }
    if (list.length === 1) {
      if (this.hasScoringWrapperTarget) this.scoringWrapperTarget.style.display = 'none'
      select.innerHTML = `<option value="${list[0].id}" selected="selected">${list[0].name}</option>`
      if (this.hasScoringInfoTarget) this.scoringInfoTarget.innerHTML = this.renderInfo(list[0])
      return
    }
    if (this.hasScoringWrapperTarget) this.scoringWrapperTarget.style.display = 'block'
    select.innerHTML = ''
    const placeholder = document.createElement('option')
    placeholder.value = ''
    placeholder.textContent = window.I18n?.t('tournaments.scoring.select_prompt') || 'Select scoring system'
    select.appendChild(placeholder)
    const def = list.find(s => s.is_default) || list[0]
    list.forEach(s => {
      const opt = document.createElement('option')
      opt.value = String(s.id)
      opt.textContent = s.name
      if (def && def.id === s.id) opt.selected = true
      select.appendChild(opt)
    })
    if (this.hasScoringInfoTarget) this.scoringInfoTarget.innerHTML = this.renderInfo(def)
    select.addEventListener('change', () => {
      const id = select.value
      const chosen = list.find(s => String(s.id) === String(id)) || null
      if (this.hasScoringInfoTarget) this.scoringInfoTarget.innerHTML = chosen ? this.renderInfo(chosen) : ''
    })
  }

  renderInfo(item) {
    if (!item) return ''
    const summary = item.summary ? `<div class="card-date" style="font-style:normal;">${item.summary}</div>` : ''
    const desc = item.description_html ? `<div class="card" style="padding:0.5rem; margin-top:0.25rem;">${item.description_html}</div>` : ''
    return `<div><strong>${item.name}</strong>${summary}${desc}</div>`
  }
} 