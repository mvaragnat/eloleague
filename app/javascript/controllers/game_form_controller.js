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
    const selectedContainer = form.querySelector('[data-player-search-target="selected"]')
    const selected = selectedContainer ? selectedContainer.querySelectorAll('.selected-player') : []

    // In tournament flow, we need exactly two players selected (A and B)
    if (this.twoPlayersValue) {
      if (!selected || selected.length !== 2) {
        event.preventDefault()
        this.showError(window.I18n?.t('games.errors.exactly_two_players') || 'Select exactly two players')
        return
      }
    } else {
      // Casual game flow: current user + one selected opponent
      if (!selected || selected.length !== 1) {
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

    // Sync selected user_ids into nested fields when in two-player mode
    if (this.twoPlayersValue) {
      // Remove previous user_id inputs to avoid duplicates
      form.querySelectorAll('input[name$="[user_id]"]').forEach(n => n.remove())
      // Ensure we have two nested participation slots [0] and [1]
      const aUserId = selected[0].getAttribute('data-user-id')
      const bUserId = selected[1].getAttribute('data-user-id')
      const aHidden = document.createElement('input')
      aHidden.type = 'hidden'
      aHidden.name = 'game_event[game_participations_attributes][0][user_id]'
      aHidden.value = aUserId
      const bHidden = document.createElement('input')
      bHidden.type = 'hidden'
      bHidden.name = 'game_event[game_participations_attributes][1][user_id]'
      bHidden.value = bUserId
      form.appendChild(aHidden)
      form.appendChild(bHidden)
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
    const selectedContainer = this.element.querySelector('[data-player-search-target="selected"]')
    const hasOpponent = selectedContainer && selectedContainer.querySelectorAll('.selected-player').length === 1
    if (this.hasScoresTarget) {
      this.scoresTarget.classList.toggle('hidden', !hasOpponent)
    }

    this.updatePlayerNames()
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
} 