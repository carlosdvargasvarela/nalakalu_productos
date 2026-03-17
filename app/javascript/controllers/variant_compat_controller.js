import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["searchInput", "item", "badge", "checkbox"];

  connect() {
    this.updateBadges();
  }

  // Filtra las variantes dentro de un acordeón específico
  filter(event) {
    const query = event.target.value.toLowerCase().trim();
    const accordionId = event.target.dataset.accordionId;

    this.itemTargets.forEach((item) => {
      if (item.dataset.accordionId === accordionId) {
        const text = item.dataset.searchText.toLowerCase();
        item.classList.toggle("d-none", !text.includes(query));
      }
    });
  }

  // Actualiza el contador de variantes seleccionadas en la cabecera del acordeón
  updateBadges() {
    const counts = {};

    this.checkboxTargets.forEach((cb) => {
      if (cb.checked) {
        const typeId = cb.dataset.typeId;
        counts[typeId] = (counts[typeId] || 0) + 1;
      }
    });

    this.badgeTargets.forEach((badge) => {
      const typeId = badge.dataset.typeId;
      const count = counts[typeId] || 0;

      if (count > 0) {
        badge.textContent = `${count} seleccionada${count !== 1 ? "s" : ""}`;
        badge.classList.remove("d-none");
      } else {
        badge.classList.add("d-none");
      }
    });
  }
}
