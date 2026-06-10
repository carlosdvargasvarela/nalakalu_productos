import { Controller } from "@hotwired/stimulus"

const PRESETS = {
  daily_6am:      "0 6 * * *",
  daily_midnight: "0 0 * * *",
  weekly_monday:  "0 6 * * 1",
  hourly:         "0 * * * *"
}

export default class extends Controller {
  static targets = [
    "testResults", "testSpinner",
    "cronPreset", "cronInput", "cronPreview",
    "daysBack", "daysForward", "datePreview"
  ]
  static values = {
    testUrl: String,
    showrooms: Array
  }

  connect() {
    this.#updateDatePreview()
  }

  // ── Test de clasificación ─────────────────────────────────────────────────

  async runTest(event) {
    event.preventDefault()
    const form = event.currentTarget.closest("form")
    const data = new FormData(form)

    this.testResultsTarget.innerHTML = ""
    this.testSpinnerTarget.classList.remove("d-none")

    try {
      const resp = await fetch(this.testUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
          "Accept": "application/json"
        },
        body: data
      })
      const json = await resp.json()
      this.testSpinnerTarget.classList.add("d-none")
      this.#renderTestResults(json)
    } catch {
      this.testSpinnerTarget.classList.add("d-none")
      this.testResultsTarget.innerHTML =
        `<div class="alert alert-danger">Error de red al simular.</div>`
    }
  }

  #renderTestResults(json) {
    if (!json.matched) {
      this.testResultsTarget.innerHTML = `
        <div class="alert alert-warning mb-0">
          <i class="bi bi-x-circle me-2"></i>
          El pedido <strong>${json.order_number || "—"}</strong> no matchea ninguna regla de clasificación.
          No generaría movimientos.
        </div>`
      return
    }

    const rows = json.movements.map(m => {
      const badge = m.type === "entry"
        ? `<span class="badge bg-success">Entrada</span>`
        : `<span class="badge bg-danger">Salida</span>`
      return `<tr><td>${badge}</td><td class="fw-semibold">${m.showroom}</td></tr>`
    }).join("")

    this.testResultsTarget.innerHTML = `
      <div class="alert alert-success mb-2">
        <i class="bi bi-check-circle me-2"></i>
        <strong>${json.movements.length}</strong> movimiento(s) se generarían para
        el pedido <strong>${json.order_number}</strong>.
      </div>
      <table class="table table-sm table-bordered mb-0">
        <thead class="table-light"><tr><th>Tipo</th><th>Sala</th></tr></thead>
        <tbody>${rows}</tbody>
      </table>`
  }

  // ── Cron preset ──────────────────────────────────────────────────────────

  updatePreset(event) {
    const preset = event.target.value
    if (PRESETS[preset]) {
      this.cronInputTarget.value = PRESETS[preset]
      this.cronInputTarget.readOnly = true
    } else {
      this.cronInputTarget.readOnly = false
    }
    this.#updateCronPreview()
  }

  updateCron() {
    this.#updateCronPreview()
  }

  #updateCronPreview() {
    const cron = this.cronInputTarget.value
    this.cronPreviewTarget.textContent = cron ? `Expresión activa: ${cron}` : ""
  }

  // ── Preview de fechas ─────────────────────────────────────────────────────

  updateDatePreview() {
    this.#updateDatePreview()
  }

  #updateDatePreview() {
    if (!this.hasDatePreviewTarget) return
    const back    = parseInt(this.daysBackTarget.value)    || 0
    const forward = parseInt(this.daysForwardTarget.value) || 0
    const from    = new Date(); from.setDate(from.getDate() - back)
    const to      = new Date(); to.setDate(to.getDate() + forward)
    const fmt = d => d.toLocaleDateString("es-CR", { day: "2-digit", month: "2-digit", year: "numeric" })
    this.datePreviewTarget.textContent = `Con estos valores: ${fmt(from)} – ${fmt(to)}`
  }
}
