import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["card", "cardBody", "icon", "radio"];

  connect() {
    // Aplicar estado visual al cargar según el radio ya seleccionado
    this.radioTargets.forEach((radio) => {
      if (radio.checked)
        this.applyActive(
          radio.closest("[data-procurement-strategy-target='card']"),
        );
      else
        this.applyInactive(
          radio.closest("[data-procurement-strategy-target='card']"),
        );
    });
  }

  select(event) {
    const selectedCard = event.target.closest(
      "[data-procurement-strategy-target='card']",
    );
    this.cardTargets.forEach((card) => this.applyInactive(card));
    this.applyActive(selectedCard);
  }

  applyActive(card) {
    const value = card.dataset.value;
    const color = value === "individual" ? "primary" : "info";
    const body = card.querySelector(
      "[data-procurement-strategy-target='cardBody']",
    );
    const icon = card.querySelector(
      "[data-procurement-strategy-target='icon']",
    );
    const i = icon.querySelector("i");

    body.className = `card border-2 rounded-4 p-3 h-100 border-${color} bg-${color} bg-opacity-5`;
    icon.style.backgroundColor = `var(--bs-${color})`;
    i.className = i.className.replace(/text-\w+/, "") + " text-white";
  }

  applyInactive(card) {
    const body = card.querySelector(
      "[data-procurement-strategy-target='cardBody']",
    );
    const icon = card.querySelector(
      "[data-procurement-strategy-target='icon']",
    );
    const i = icon.querySelector("i");

    body.className = "card border-2 rounded-4 p-3 h-100 border-light";
    icon.style.backgroundColor = "var(--bs-light)";
    i.className = i.className.replace(/text-\w+/, "") + " text-muted";
  }
}
