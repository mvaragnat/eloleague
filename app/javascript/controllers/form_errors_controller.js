import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["summary"]

  connect() {
    if (!this.hasSummaryTarget) return
    if (this.summaryTarget.classList.contains("hidden")) return
    this.focusFirstInvalidField()
  }

  focusFirstInvalidField() {
    const firstInvalid = this.element.querySelector('[aria-invalid="true"], .input-error')
    if (!firstInvalid || typeof firstInvalid.focus !== "function") return

    firstInvalid.scrollIntoView({ behavior: "smooth", block: "center" })
    firstInvalid.focus({ preventScroll: true })
  }
}
