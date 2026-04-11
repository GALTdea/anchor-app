import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "scaleConfig", "optionsConfig"]

  connect() {
    this.toggleConfig()
  }

  toggleConfig() {
    const type = this.typeTarget.value

    this.scaleConfigTarget.hidden = type !== "scale"
    this.optionsConfigTarget.hidden = type !== "select"
  }
}
