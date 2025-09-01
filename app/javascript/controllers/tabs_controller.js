import { Controller } from "@hotwired/stimulus"

// data-controller="tabs"
// data-tabs-target="tab" for buttons and data-tabs-target="panel" for panels
// Optional: data-tabs-active-index-value to set initial active tab (default 0)
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeIndex: { type: Number, default: 0 } }

  connect() {
    this.show(this.activeIndexValue)
  }

  select(event) {
    event.preventDefault()
    const index = Number(event.currentTarget.dataset.index)
    this.show(index)

    // Persist tab in URL without reloading
    try {
      const url = new URL(window.location.href)
      url.searchParams.set('tab', index)
      window.history.replaceState({}, '', url)
    } catch (_) {
      // No-op if URL API not available
    }
  }

  show(index) {
    this.activeIndexValue = index

    this.tabTargets.forEach((el, i) => {
      const selected = i === index
      el.setAttribute("aria-selected", selected ? "true" : "false")
      el.classList.toggle("btn-primary", selected)
    })

    this.panelTargets.forEach((el, i) => {
      el.style.display = i === index ? "block" : "none"
    })
  }
} 