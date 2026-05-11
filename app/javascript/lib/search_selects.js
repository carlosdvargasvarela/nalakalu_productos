import TomSelect from "tom-select"

function applyTomSelect(scope = document) {
  scope.querySelectorAll("select").forEach(el => {
    if (el.tomselect) return
    if (el.dataset.noTomselect !== undefined) return

    const hasBlank = el.options[0] && el.options[0].value === ""
    const plugins = hasBlank && !el.multiple ? ["clear_button"] : []

    new TomSelect(el, {
      allowEmptyOption: true,
      placeholder: "Buscar...",
      plugins,
      onInitialize() {
        if (hasBlank) this.clear()
      }
    })
  })
}

function destroyTomSelects(scope = document) {
  scope.querySelectorAll("select").forEach(el => {
    if (el.tomselect) {
      el.tomselect.destroy()
    }
  })
}

document.addEventListener("turbo:load", () => applyTomSelect())
document.addEventListener("turbo:frame-load", e => applyTomSelect(e.target))
document.addEventListener("turbo:before-cache", () => destroyTomSelects())

export { applyTomSelect }
