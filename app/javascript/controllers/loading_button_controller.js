import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  submit() {
    if (!this.hasButtonTarget) return
    const btn = this.buttonTarget
    btn.disabled = true
    this._originalHtml = btn.innerHTML
    btn.innerHTML = `<span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>Sincronizando...`

    // Safety reset after 30s in case Turbo does not navigate away
    this._timeout = setTimeout(() => {
      btn.disabled = false
      btn.innerHTML = this._originalHtml
    }, 30000)
  }

  disconnect() {
    clearTimeout(this._timeout)
  }
}
