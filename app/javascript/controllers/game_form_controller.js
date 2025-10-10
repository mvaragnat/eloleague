import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["error", "scores"]
  static values = { factionsUrl: String, twoPlayers: Boolean }

  connect() {
    const systemSelect = this.element.querySelector('select[name="game_event[game_system_id]"]')
    if (systemSelect && systemSelect.value) {
      this.loadFactions({ currentTarget: systemSelect })
    }

    // Keep player names visible above each participation block
    this.updatePlayerNames()
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
} 