import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "selected", "container"]
  static values = { maxSelections: Number, preselectedUserId: Number, preselectedUsername: String, removable: Boolean }

  connect() {
    this.selectedPlayers = []

    // Optional preselection (e.g., default current user as Player A)
    if (this.hasPreselectedUserIdValue && this.preselectedUserIdValue) {
      const id = String(this.preselectedUserIdValue)
      const name = this.preselectedUsernameValue || ''
      if (!this.selectedPlayers.includes(id)) {
        this.selectedPlayers.push(id)
        this.selectedTarget.insertAdjacentHTML('beforeend', this.selectedPlayerTemplate(id, name))
      }
    }

    this.updateContainerVisibility()
  }

  search() {
    const query = this.inputTarget.value
    if (query.length < 1) {
      this.resultsTarget.innerHTML = ''
      return
    }

    const tId = this.inputTarget.dataset.tournamentId
    const url = tId ? `/users/search?q=${encodeURIComponent(query)}&tournament_id=${encodeURIComponent(tId)}`
                    : `/users/search?q=${encodeURIComponent(query)}`

    fetch(url)
      .then(response => response.json())
      .then(data => this.showResults(data))
  }

  showResults(users) {
    const filtered = users
      .filter(user => !this.selectedPlayers.includes(String(user.id)))
      .slice(0, 10)

    if (filtered.length === 0) {
      const msg = (window.I18n && window.I18n.t && window.I18n.t('games.search.no_results')) || 'No results found'
      this.resultsTarget.innerHTML = `<div style="padding:0.75rem;color:#6b7280;">${msg}</div>`
      return
    }

    this.resultsTarget.innerHTML = filtered
      .map(user => this.userTemplate(user))
      .join('')
  }

  selectPlayer(event) {
    const userId = event.currentTarget.dataset.playerSearchUserId
    const username = event.currentTarget.dataset.playerSearchUsername
    if (this.selectedPlayers.includes(String(userId))) return

    const maxSel = this.hasMaxSelectionsValue ? this.maxSelectionsValue : 1
    if (this.selectedPlayers.length >= maxSel) return

    this.selectedPlayers.push(String(userId))
    this.selectedTarget.insertAdjacentHTML('beforeend', this.selectedPlayerTemplate(userId, username))
    this.resultsTarget.innerHTML = ''
    this.inputTarget.value = ''

    this.updateContainerVisibility()

    this.element.dispatchEvent(new CustomEvent('player-selected', { bubbles: true, detail: { userId, username } }))
  }

  removePlayer(event) {
    const { userId } = event.currentTarget.dataset
    this.selectedPlayers = this.selectedPlayers.filter(id => id !== String(userId))
    event.currentTarget.closest('.selected-player').remove()

    this.updateContainerVisibility()

    this.element.dispatchEvent(new CustomEvent('player-removed', { bubbles: true, detail: { userId } }))
  }

  updateContainerVisibility() {
    if (!this.hasContainerTarget) return
    const maxSel = this.hasMaxSelectionsValue ? this.maxSelectionsValue : 1
    this.containerTarget.style.display = this.selectedPlayers.length >= maxSel ? 'none' : ''
  }

  userTemplate(user) {
    return `
      <div data-action="click->player-search#selectPlayer"
           data-player-search-user-id="${user.id}"
           data-player-search-username="${user.username}">
        <strong>${user.username}</strong>
      </div>
    `
  }

  selectedPlayerTemplate(userId, username) {
    const canRemove = this.hasRemovableValue ? this.removableValue : true
    const removeButton = canRemove ? `
        <button type="button"
                data-action="click->player-search#removePlayer"
                data-user-id="${userId}">×</button>
      ` : ''

    return `
      <div class="selected-player" data-user-id="${userId}">
        <span><strong>${username}</strong></span>
        ${removeButton}
      </div>
    `
  }
}