import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.originalBodyOverflow = document.body.style.overflow
    this.originalBodyPaddingRight = document.body.style.paddingRight

    const scrollbarWidth = window.innerWidth - document.documentElement.clientWidth
    if (scrollbarWidth > 0) {
      document.body.style.paddingRight = `${scrollbarWidth}px`
    }
    document.body.style.overflow = 'hidden'
  }

  disconnect() {
    this.unlockScroll()
  }

  close(event) {
    event?.preventDefault()
    const frame = document.getElementById('modal')
    if (frame) {
      frame.innerHTML = ''
    }
    this.unlockScroll()
  }

  unlockScroll() {
    document.body.style.overflow = this.originalBodyOverflow || ''
    document.body.style.paddingRight = this.originalBodyPaddingRight || ''
  }
}