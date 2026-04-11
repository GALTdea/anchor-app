import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questionList", "questionTemplate"]

  connect() {
    this.questionIndex = this.questionListTarget.querySelectorAll("[data-question-item]").length
  }

  addQuestion() {
    const html = this.questionTemplateTarget.innerHTML.replaceAll("__QUESTION_INDEX__", this.questionIndex)
    this.questionListTarget.insertAdjacentHTML("beforeend", html)
    this.questionIndex += 1
  }
}
