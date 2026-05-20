import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoDismiss: Boolean,
    timeout: { type: Number, default: 4000 }
  }

  connect() {
    if (!this.autoDismissValue) return

    this.timeoutId = window.setTimeout(() => {
      this.dismiss()
    }, this.timeoutValue)
  }

  disconnect() {
    this.clearTimer()
  }

  dismiss() {
    this.clearTimer()
    this.element.remove()
  }

  clearTimer() {
    if (!this.timeoutId) return

    window.clearTimeout(this.timeoutId)
    this.timeoutId = null
  }
}
