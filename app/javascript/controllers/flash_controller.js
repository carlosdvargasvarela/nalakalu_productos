import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => this.dismiss(), 4500)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.remove("show")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
  }
}
