import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tournament-form"
export default class extends Controller {
  static targets = ["format", "rounds", "locationBlock"]

  connect() {
    this.toggleRounds()
    this.toggleOnline()
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
} 