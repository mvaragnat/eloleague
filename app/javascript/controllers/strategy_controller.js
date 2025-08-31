import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    updateUrl: String,
    savedText: String,
    showPairing: Boolean,
    explainPairing: Object,
    explainTiebreak: Object
  }

  static targets = ["pairingExplanation", "tiebreak1Explanation", "tiebreak2Explanation"]

  async changed(event) {
    const element = event.currentTarget
    const field = element.dataset.field
    let value
    if (element.type === "checkbox") {
      value = element.checked ? "1" : "0"
    } else {
      value = element.value
    }

    const formData = new FormData()
    formData.append(`tournament[${field}]`, value)

    const response = await fetch(this.updateUrlValue, {
      method: "PATCH",
      headers: { "X-CSRF-Token": this.csrfToken(), "Accept": "application/json" },
      body: formData,
      credentials: "same-origin"
    })

    if (response.ok) {
      this.updateExplanation(field, value)
      this.showFlash(this.savedTextValue, "notice")
    } else {
      const msg = (await response.text()) || "Error"
      this.showFlash(msg, "alert")
    }
  }

  updateExplanation(field, value) {
    if (field === "pairing_strategy_key" && this.hasPairingExplanationTarget) {
      const txt = this.explainPairingValue[value] || this.explainPairingValue["default"] || ""
      this.pairingExplanationTarget.textContent = txt
    }
    if (field === "tiebreak1_strategy_key" && this.hasTiebreak1ExplanationTarget) {
      const txt = this.explainTiebreakValue[value] || this.explainTiebreakValue["default"] || ""
      this.tiebreak1ExplanationTarget.textContent = txt
    }
    if (field === "tiebreak2_strategy_key" && this.hasTiebreak2ExplanationTarget) {
      const txt = this.explainTiebreakValue[value] || this.explainTiebreakValue["default"] || ""
      this.tiebreak2ExplanationTarget.textContent = txt
    }
  }

  showFlash(message, type) {
    const container = document.createElement("div")
    container.className = "flash-container"

    const flash = document.createElement("div")
    flash.className = `flash ${type === "alert" ? "flash--alert" : "flash--notice"}`
    flash.setAttribute("role", type === "alert" ? "alert" : "status")

    const icon = document.createElement("span")
    icon.className = "flash-icon"
    icon.textContent = type === "alert" ? "⚠️" : "✅"

    const span = document.createElement("span")
    span.textContent = message

    flash.appendChild(icon)
    flash.appendChild(span)
    container.appendChild(flash)

    const main = document.querySelector("main")
    if (main) {
      main.insertBefore(container, main.firstChild)
      setTimeout(() => container.remove(), 2500)
    }
  }

  csrfToken() {
    const tag = document.querySelector('meta[name="csrf-token"]')
    return tag && tag.getAttribute('content')
  }
} 