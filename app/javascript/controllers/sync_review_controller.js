import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "productSelect", "newProductName", "newProductCode", "newProductFamily", "quickCreateError",
    "movementRow", "orderGroup", "bulkCount", "bulkIgnoreBtn", "bulkAssignBtn",
    "bulkAssignProductSelect", "selectAllUnresolved"
  ]
  static values = { quickCreateUrl: String }

  connect() {
    this._targetMovementId = null
    const hasPending       = this.movementRowTargets.some(r =>
      r.dataset.status === "suggested" || r.dataset.status === "unassigned"
    )
    this._activeFilter = hasPending ? "pending" : "all"
    this._searchTerm   = ""
    this.element.querySelectorAll("[data-action*='setFilter']").forEach(btn => {
      btn.classList.toggle("active", btn.dataset.status === this._activeFilter)
    })
    this.#applyFilters()
  }

  // ── Tabs de filtro ───────────────────────────────────────────────────────────

  setFilter(event) {
    this._activeFilter = event.currentTarget.dataset.status
    this.element.querySelectorAll("[data-action*='setFilter']").forEach(btn => {
      btn.classList.toggle("active", btn.dataset.status === this._activeFilter)
    })
    this.#applyFilters()
  }

  // ── Búsqueda ─────────────────────────────────────────────────────────────────

  search(event) {
    this._searchTerm = event.target.value.toLowerCase().trim()
    this.#applyFilters()
  }

  clearSearch(event) {
    const input = this.element.querySelector("[data-action*='search']")
    if (input) { input.value = ""; this._searchTerm = "" }
    this.#applyFilters()
  }

  // ── Bulk checkboxes ──────────────────────────────────────────────────────────

  toggleSelectAll(event) {
    const checked = event.target.checked
    this.movementRowTargets
      .filter(row => (row.dataset.status === "suggested" || row.dataset.status === "unassigned") &&
                     row.style.display !== "none")
      .forEach(row => {
        const cb = row.querySelector(".ignore-cb")
        if (cb) cb.checked = checked
      })
    this.#updateBulkCount()
  }

  checkboxChanged() {
    this.#updateBulkCount()
    this.#syncSelectAll()
  }

  submitBulkIgnore(event) {
    event.preventDefault()
    const ids = [...document.querySelectorAll(".ignore-cb:checked")].map(cb => cb.value)
    if (!ids.length) return
    this.#submitBulkForm("bulk-ignore-form", ids)
  }

  submitBulkAssignProduct(event) {
    event.preventDefault()
    const ids = [...document.querySelectorAll(".ignore-cb:checked")].map(cb => cb.value)
    const productId = this.bulkAssignProductSelectTarget.value
    if (!ids.length || !productId) return
    this.#submitBulkForm("bulk-assign-product-form", ids, { product_id: productId })
  }

  // ── Quick-create producto ────────────────────────────────────────────────────

  openQuickCreate(event) {
    event.preventDefault()
    const row = event.target.closest("[data-sync-review-target='movementRow']")
    this._targetMovementId = row?.dataset.movementId ?? null

    this.newProductNameTarget.value = ""
    this.newProductCodeTarget.value = ""
    if (this.hasNewProductFamilyTarget) this.newProductFamilyTarget.selectedIndex = 0
    this.quickCreateErrorTarget.textContent = ""
    this.quickCreateErrorTarget.classList.add("d-none")

    bootstrap.Modal.getOrCreateInstance(
      document.getElementById("quickCreateProductModal")
    ).show()
  }

  async submitQuickCreate(event) {
    event.preventDefault()
    const name = this.newProductNameTarget.value.trim()
    const code = this.newProductCodeTarget.value.trim()

    if (!name || !code) {
      this.#showQuickCreateError("Nombre y código son obligatorios.")
      return
    }

    const body = { product: { name, base_code: code } }
    if (this.hasNewProductFamilyTarget && this.newProductFamilyTarget.value) {
      body.product.family_id = this.newProductFamilyTarget.value
    }

    try {
      const resp = await fetch(this.quickCreateUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
          "Accept": "application/json"
        },
        body: JSON.stringify(body)
      })
      const data = await resp.json()

      if (resp.ok) {
        this.#distributeOption(data.id, data.name)
        // Re-query by movement ID instead of using a possibly-stale DOM reference
        const targetRow = this._targetMovementId
          ? this.movementRowTargets.find(r => r.dataset.movementId === this._targetMovementId)
          : null
        const sel = targetRow?.querySelector("[data-sync-review-target='productSelect']")
        if (sel) {
          sel.tomselect
            ? sel.tomselect.setValue(String(data.id))
            : (sel.value = String(data.id))
        }
        bootstrap.Modal.getInstance(
          document.getElementById("quickCreateProductModal")
        ).hide()
      } else {
        this.#showQuickCreateError(data.error || "Error al crear el producto.")
      }
    } catch {
      this.#showQuickCreateError("Error de red. Intenta de nuevo.")
    }
  }

  // ── Privado ──────────────────────────────────────────────────────────────────

  #applyFilters() {
    this.movementRowTargets.forEach(row => {
      const statusMatch = this.#statusMatch(row.dataset.status)
      const text        = row.textContent.toLowerCase()
      const searchMatch = !this._searchTerm || text.includes(this._searchTerm)
      row.style.display = statusMatch && searchMatch ? "" : "none"
    })

    this.orderGroupTargets.forEach(group => {
      const rows       = group.querySelectorAll("[data-sync-review-target='movementRow']")
      const anyVisible = [...rows].some(r => r.style.display !== "none")
      group.style.display = anyVisible ? "" : "none"
    })

    this.#updateBulkCount()
    this.#syncSelectAll()
  }

  #statusMatch(status) {
    switch (this._activeFilter) {
      case "all":        return true
      case "pending":    return status === "unassigned" || status === "suggested"
      case "unassigned": return status === "unassigned"
      case "suggested":  return status === "suggested"
      case "resolved":   return status === "resolved"
      case "ignored":    return status === "ignored"
      default:           return true
    }
  }

  #updateBulkCount() {
    const count = document.querySelectorAll(".ignore-cb:checked").length
    if (this.hasBulkCountTarget)     this.bulkCountTarget.textContent = count > 0 ? count : ""
    if (this.hasBulkIgnoreBtnTarget) this.bulkIgnoreBtnTarget.disabled = count === 0
    if (this.hasBulkAssignBtnTarget) this.bulkAssignBtnTarget.disabled = count === 0
  }

  #submitBulkForm(formId, ids, extraFields = {}) {
    const form = document.getElementById(formId)
    form.querySelectorAll("input[data-bulk-field]").forEach(el => el.remove())
    ids.forEach(id => {
      const inp = document.createElement("input")
      inp.type = "hidden"
      inp.name = "movement_ids[]"
      inp.value = id
      inp.dataset.bulkField = "true"
      form.appendChild(inp)
    })
    Object.entries(extraFields).forEach(([name, value]) => {
      const inp = document.createElement("input")
      inp.type = "hidden"
      inp.name = name
      inp.value = value
      inp.dataset.bulkField = "true"
      form.appendChild(inp)
    })
    form.submit()
  }

  #syncSelectAll() {
    if (!this.hasSelectAllUnresolvedTarget) return
    const allCbs = [...document.querySelectorAll(".ignore-cb")]
      .filter(cb => cb.closest("tr")?.style.display !== "none")
    const checkedCount = allCbs.filter(cb => cb.checked).length
    this.selectAllUnresolvedTarget.checked       = checkedCount === allCbs.length && allCbs.length > 0
    this.selectAllUnresolvedTarget.indeterminate = checkedCount > 0 && checkedCount < allCbs.length
  }

  #distributeOption(id, name) {
    const strId = String(id)
    document.querySelectorAll("select[data-product-select]").forEach(sel => {
      if (!sel.querySelector(`option[value="${strId}"]`)) {
        const after = [...sel.options].find(o => o.value !== "" && o.text.localeCompare(name) > 0)
        const opt   = new Option(name, strId)
        after ? sel.insertBefore(opt, after) : sel.appendChild(opt)
      }
      if (sel.tomselect && !sel.tomselect.options[strId]) {
        sel.tomselect.addOption({ value: strId, text: name })
      }
    })
  }

  #showQuickCreateError(msg) {
    this.quickCreateErrorTarget.textContent = msg
    this.quickCreateErrorTarget.classList.remove("d-none")
  }
}
