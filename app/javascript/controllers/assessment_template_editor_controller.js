import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sectionList", "sectionTemplate"]

  connect() {
    this.sectionIndex = this.sectionListTarget.querySelectorAll("[data-section-item]").length
  }

  addSection() {
    const html = this.sectionTemplateTarget.innerHTML.replaceAll("__SECTION_INDEX__", this.sectionIndex)
    this.sectionListTarget.insertAdjacentHTML("beforeend", html)
    this.sectionIndex += 1
  }

  removeItem(event) {
    const item = event.currentTarget.closest("[data-section-item], [data-question-item]")
    if (!item) return

    const destroyField = item.querySelector("[data-destroy-field]")
    if (destroyField) destroyField.value = "1"
    item.hidden = true
  }
}
