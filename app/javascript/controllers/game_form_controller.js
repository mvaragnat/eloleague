import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["error", "scores"]
  static values = { factionsUrl: String, scoringSystemsUrl: String, twoPlayers: Boolean }

  connect() {
    const systemSelect = this.element.querySelector('select[name="game_event[game_system_id]"]')
    if (systemSelect && systemSelect.value) {
      this.loadFactions({ currentTarget: systemSelect })
    }

    // Keep player names visible above each participation block
    this.updatePlayerNames()

    // Try to apply any preset factions coming from preselected players (participant flow)
    // This is especially needed if the player-selected event fired before this controller connected.
    this.applyPresetFactions()
  }

  validate(event) {
    const form = this.element

    // Two independent player selectors (one per participation block)
    const blocks = Array.from(form.querySelectorAll('.participation-block'))
    const selectionsPerBlock = blocks.map(block => block.querySelectorAll('[data-player-search-target="selected"] .selected-player').length)

    if (this.twoPlayersValue) {
      const allHaveOne = selectionsPerBlock.length === 2 && selectionsPerBlock.every(n => n === 1)
      if (!allHaveOne) {
        event.preventDefault()
        this.showError(window.I18n?.t('games.errors.exactly_two_players') || 'Select exactly two players')
        return
      }
    } else {
      // Fallback: at least one selected in the first block
      if (selectionsPerBlock[0] !== 1) {
        event.preventDefault()
        this.showError(window.I18n?.t('games.errors.exactly_two_players') || 'Select exactly two players')
        return
      }
    }

    // Verify scores present for both participations
    const scoreInputs = form.querySelectorAll('input[name^="game_event[game_participations_attributes]"][name$="[score]"]')
    const allScoresPresent = Array.from(scoreInputs).every(i => (i.value || '').trim() !== '')
    if (!allScoresPresent) {
      event.preventDefault()
      this.showError(window.I18n?.t('games.errors.both_scores_required') || 'Both scores are required')
      return
    }

    // Hidden user_id fields are inside each participation block; ensure they are set
    const userInputs = Array.from(form.querySelectorAll('input[name^="game_event[game_participations_attributes]"][name$="[user_id]"]'))
    const allUsersPresent = userInputs.length >= 2 && userInputs.every(i => (i.value || '').trim() !== '')
    if (!allUsersPresent) {
      event.preventDefault()
      this.showError(window.I18n?.t('games.errors.exactly_two_players') || 'Select exactly two players')
      return
    }

    // Require factions for both
    const factionSelects = form.querySelectorAll('select[name^="game_event[game_participations_attributes]"][name$="[faction_id]"]')
    const allFactionsPresent = Array.from(factionSelects).every(s => (s.value || '').trim() !== '')
    if (!allFactionsPresent) {
      event.preventDefault()
      this.showError(window.I18n?.t('games.errors.both_factions_required') || 'Both players must select a faction')
      return
    }

    this.hideError()
  }

  async loadFactions(event) {
    const systemSelect = event?.currentTarget || this.element.querySelector('select[name="game_event[game_system_id]"]')
    const systemId = systemSelect?.value

    const factionSelects = Array.from(this.element.querySelectorAll('[data-faction-select="true"]'))

    if (!systemId) {
      factionSelects.forEach(select => this.populateSelect(select, []))
      this.toggleScores()
      this.populateScoringSystems([], null)
      return
    }

    try {
      const url = `${this.factionsUrlValue}?game_system_id=${encodeURIComponent(systemId)}`
      const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      if (!response.ok) throw new Error("Network error")
      const factions = await response.json()
      factionSelects.forEach(select => this.populateSelect(select, factions))
    } catch (_e) {
      factionSelects.forEach(select => this.populateSelect(select, []))
    } finally {
      this.toggleScores()
      // After factions options are populated, apply any preset faction ids
      this.applyPresetFactions()
    }

    // Also load scoring systems for this game system
    try {
      if (!this.hasScoringSystemsUrlValue) return
      const url = `${this.scoringSystemsUrlValue}?game_system_id=${encodeURIComponent(systemId)}`
      const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      if (!response.ok) throw new Error("Network error")
      const list = await response.json()
      const defaultItem = list.find(s => s.is_default) || list[0] || null
      this.populateScoringSystems(list, defaultItem)
    } catch (_e) {
      this.populateScoringSystems([], null)
    }
  }

  populateSelect(select, factions) {
    const prompt = select.querySelector('option[value=""]')?.textContent || (window.I18n?.t('games.new.select_faction') || 'Select faction')
    const previous = select.value

    // Reset options
    select.innerHTML = ''
    const placeholder = document.createElement('option')
    placeholder.value = ''
    placeholder.textContent = prompt
    select.appendChild(placeholder)

    factions.forEach(f => {
      const option = document.createElement('option')
      option.value = String(f.id)
      option.textContent = f.name
      select.appendChild(option)
    })

    if (factions.some(f => String(f.id) === previous)) {
      select.value = previous
    } else {
      select.value = ''
    }

    // Trigger change for dependent UI, if any
    select.dispatchEvent(new Event('change', { bubbles: true }))
  }

  populateScoringSystems(list, selected) {
    const select = this.element.querySelector('select[name="game_event[scoring_system_id]"]')
    const info = this.element.querySelector('[data-scoring-info]')
    const wrapper = this.element.querySelector('[data-scoring-select-wrapper]')
    if (!select || !info || !wrapper) return

    // Reset
    select.innerHTML = ''
    if (!list || list.length === 0) {
      wrapper.style.display = 'none'
      info.innerHTML = ''
      return
    }

    if (list.length === 1) {
      // Single: set hidden value and show info
      wrapper.style.display = 'none'
      select.innerHTML = `<option value="${list[0].id}" selected="selected">${list[0].name}</option>`
      info.innerHTML = this.renderScoringInfo(list[0])
      if (!list[0].description_html) {
        this._loadScoringSystemDetails(list[0].id).then(item => {
          if (item) info.innerHTML = this.renderScoringInfo(item)
        }).catch(() => {})
      }
      return
    }

    // Multiple: show select and info
    wrapper.style.display = 'block'
    const placeholder = document.createElement('option')
    placeholder.value = ''
    placeholder.textContent = window.I18n?.t('games.scoring.select_prompt') || 'Select scoring system'
    select.appendChild(placeholder)
    list.forEach(s => {
      const opt = document.createElement('option')
      opt.value = String(s.id)
      opt.textContent = s.name
      if (selected && selected.id === s.id) opt.selected = true
      select.appendChild(opt)
    })
    // Update info
    info.innerHTML = this.renderScoringInfo(selected || list[0])
    // Bind change
    select.addEventListener('change', () => {
      const id = select.value
      const chosen = list.find(s => String(s.id) === String(id)) || null
      info.innerHTML = chosen ? this.renderScoringInfo(chosen) : ''
      if (chosen && !chosen.description_html) {
        this._loadScoringSystemDetails(chosen.id).then(item => {
          if (item) info.innerHTML = this.renderScoringInfo(item)
        }).catch(() => {})
      }
    })
  }

  renderScoringInfo(item) {
    if (!item) return ''
    const summary = item.summary ? `<div class="card-date" style="font-style:normal;">${item.summary}</div>` : ''
    const desc = item.description_html ? `<div class="card" style="padding:0.5rem; margin-top:0.25rem;">${item.description_html}</div>` : ''
    return `<div><strong>${item.name}</strong>${summary}${desc}</div>`
  }

  async _loadScoringSystemDetails(id) {
    try {
      const base = String(this.scoringSystemsUrlValue || '').replace(/\?.*$/, '')
      if (!base) return null
      const url = `${base}/${encodeURIComponent(id)}`
      const res = await fetch(url, { headers: { 'Accept': 'application/json' }, credentials: 'same-origin' })
      if (!res.ok) return null
      return await res.json()
    } catch (_e) {
      return null
    }
  }

  showScores() {
    if (this.hasScoresTarget) {
      this.scoresTarget.classList.remove('hidden')
    }
  }

  toggleScores() {
    // No-op in two-selector layout; retain for backward compatibility
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove('hidden')
  }

  hideError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ''
    this.errorTarget.classList.add('hidden')
  }

  // Update player name headings based on selected players
  updatePlayerNames() {
    const selected = Array.from(this.element.querySelectorAll('[data-player-search-target="selected"] .selected-player'))
    const nameNodes = Array.from(this.element.querySelectorAll('[data-player-name]'))
    if (nameNodes.length === 0) return

    // Fill names for up to two players; leave blank if missing
    for (let i = 0; i < nameNodes.length; i += 1) {
      const node = nameNodes[i]
      const sel = selected[i]
      if (sel) {
        const usernameEl = sel.querySelector('strong')
        node.textContent = usernameEl ? usernameEl.textContent : ''
      } else {
        node.textContent = ''
      }
    }
  }

  // Map selection events to the correct hidden input within the same participation block
  onPlayerSelected(event) {
    const { userId, factionId } = event.detail || {}
    if (!userId) return
    const block = event.target?.closest('.participation-block')
    if (!block) return
    const input = block.querySelector('input[name^="game_event[game_participations_attributes]"][name$="[user_id]"]')
    if (input) input.value = String(userId)

    // If a factionId is provided (tournament context), preselect it for this block
    if (factionId) {
      const factionSelect = block.querySelector('select[name^="game_event[game_participations_attributes]"][name$="[faction_id]"]')
      if (factionSelect) {
        const desired = String(factionId)
        // Try immediately, then retry a few times while factions load
        let attempts = 0
        const trySet = () => {
          attempts += 1
          const hasOption = Array.from(factionSelect.options).some(o => o.value === desired)
          if (hasOption) {
            factionSelect.value = desired
            factionSelect.dispatchEvent(new Event('change', { bubbles: true }))
            return true
          }
          return false
        }

        if (!trySet()) {
          const interval = setInterval(() => {
            if (trySet() || attempts >= 20) clearInterval(interval)
          }, 50)
        }
      }
    }
  }

  onPlayerRemoved(event) {
    const block = event.target?.closest('.participation-block')
    if (!block) return
    const input = block.querySelector('input[name^="game_event[game_participations_attributes]"][name$="[user_id]"]')
    if (input) input.value = ''
  }

  // Read any already-selected chips in each participation block and set faction selects accordingly
  applyPresetFactions() {
    const blocks = Array.from(this.element.querySelectorAll('.participation-block'))
    blocks.forEach(block => {
      const chip = block.querySelector('[data-player-search-target="selected"] .selected-player')
      if (!chip) return
      const factionId = chip.getAttribute('data-faction-id')
      if (!factionId) return
      const select = block.querySelector('select[name^="game_event[game_participations_attributes]"][name$="[faction_id]"]')
      if (!select) return
      const desired = String(factionId)
      const hasOption = Array.from(select.options).some(o => o.value === desired)
      if (hasOption) {
        select.value = desired
        select.dispatchEvent(new Event('change', { bubbles: true }))
      }
    })
  }
} 