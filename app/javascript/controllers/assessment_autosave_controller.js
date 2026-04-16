import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitter", "status"]
  static values = { delay: { type: Number, default: 600 } }

  connect() {
    this.timeout = null
  }

  disconnect() {
    this.clearTimeout()
  }

  queue() {
    this.setStatus("Saving...")
    this.clearTimeout()
    this.timeout = setTimeout(() => this.submit(), this.delayValue)
  }

  queueImmediate() {
    this.setStatus("Saving...")
    this.clearTimeout()
    this.timeout = setTimeout(() => this.submit(), 75)
  }

  submitting() {
    this.setStatus("Saving...")
  }

  submitted(event) {
    if (event.detail.success) {
      this.setStatus("Saved")
    } else {
      this.setStatus("Could not save")
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

  setStatus(message) {
    return unless this.hasStatusTarget

    this.statusTarget.textContent = message
  }
}
