import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitter", "status"]
  static values = { delay: { type: Number, default: 600 } }

  connect() {
    this.timeout = null
    this.statusTimeout = null

    if (this.hasStatusTarget && this.statusTarget.textContent.trim().length > 0) {
      this.statusTarget.classList.add("is-visible")
      this.scheduleStatusFade()
    }
  }

  disconnect() {
    this.clearTimeout()
    this.clearStatusTimeout()
  }

  queue() {
    this.setStatus("Saving...", { persist: true })
    this.clearTimeout()
    this.timeout = setTimeout(() => this.submit(), this.delayValue)
  }

  queueImmediate() {
    this.setStatus("Saving...", { persist: true })
    this.clearTimeout()
    this.timeout = setTimeout(() => this.submit(), 75)
  }

  submitting() {
    this.setStatus("Saving...", { persist: true })
  }

  submitted(event) {
    if (event.detail.success) {
      this.setStatus("Saved")
    } else {
      this.setStatus("Could not save", { persist: true })
    }
  }

  submit() {
    if (!this.hasSubmitterTarget) return

    this.element.requestSubmit(this.submitterTarget)
  }

  clearTimeout() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }

  clearStatusTimeout() {
    if (this.statusTimeout) {
      clearTimeout(this.statusTimeout)
      this.statusTimeout = null
    }
  }

  setStatus(message, { persist = false } = {}) {
    if (!this.hasStatusTarget) return

    this.clearStatusTimeout()
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("is-visible", message.length > 0)

    if (!persist) {
      this.scheduleStatusFade()
    }
  }

  scheduleStatusFade() {
    this.clearStatusTimeout()
    this.statusTimeout = setTimeout(() => {
      this.statusTarget.classList.remove("is-visible")
    }, 1800)
  }
}
