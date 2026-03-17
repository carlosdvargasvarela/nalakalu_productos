import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select", "preview", "list"];

  connect() {
    this.update();
  }

  update() {
    const rows = [];

    this.selectTargets.forEach((sel) => {
      if (sel.value) {
        rows.push({
          label: sel.dataset.propName,
          value: sel.options[sel.selectedIndex].text,
        });
      }
    });

    if (rows.length > 0) {
      this.previewTarget.classList.remove("d-none");
      this.listTarget.innerHTML = rows
        .map(
          (r) => `
        <div class="prop-preview-row">
          <span class="label">${r.label}</span>
          <span class="value">${r.value}</span>
        </div>
      `,
        )
        .join("");
    } else {
      this.previewTarget.classList.add("d-none");
      this.listTarget.innerHTML = "";
    }
  }
}
