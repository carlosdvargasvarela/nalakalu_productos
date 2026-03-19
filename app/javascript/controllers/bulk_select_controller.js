// app/javascript/controllers/bulk_select_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["checkbox", "selectAll", "counter", "toolbar", "modal"];

  connect() {
    this.bootstrapModal = new bootstrap.Modal(this.modalTarget);
    this.updateUI();
  }

  disconnect() {
    this.bootstrapModal?.dispose();
  }

  toggleAll(event) {
    const checked = event.target.checked;
    this.checkboxTargets.forEach((cb) => (cb.checked = checked));
    this.updateUI();
  }

  toggle() {
    const total = this.checkboxTargets.length;
    const selected = this.selectedIds.length;

    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = selected === total && total > 0;
      this.selectAllTarget.indeterminate = selected > 0 && selected < total;
    }
    this.updateUI();
  }

  openModal(event) {
    event.preventDefault();
    if (this.selectedIds.length === 0) return;
    // Actualizar contadores dentro del modal antes de abrirlo
    this.counterTargets.forEach(
      (el) => (el.textContent = this.selectedIds.length),
    );
    this.bootstrapModal.show();
  }

  closeModal() {
    this.bootstrapModal.hide();
  }

  updateUI() {
    const count = this.selectedIds.length;
    this.counterTargets.forEach((el) => (el.textContent = count));

    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.toggle("d-none", count === 0);
      // Mostrar toolbar como flex cuando tiene items
      if (count > 0) this.toolbarTarget.classList.add("d-flex");
      else this.toolbarTarget.classList.remove("d-flex");
    }
  }

  // Se llama con data-action="click->bulk-select#prepareSubmit"
  // en el botón submit del modal
  prepareSubmit(event) {
    event.preventDefault(); // ← clave: evitar submit prematuro

    const form = event.currentTarget.closest("form");
    if (!form) return;

    const ids = this.selectedIds;
    if (ids.length === 0) return;

    // Limpiar inputs previos
    form
      .querySelectorAll("input[name='variant_ids[]']")
      .forEach((el) => el.remove());

    // Inyectar un input hidden por cada ID seleccionado
    ids.forEach((id) => {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = "variant_ids[]";
      input.value = id;
      form.appendChild(input);
    });

    // Ahora sí hacer submit
    form.submit();
  }

  get selectedIds() {
    return this.checkboxTargets
      .filter((cb) => cb.checked)
      .map((cb) => cb.value);
  }
}
