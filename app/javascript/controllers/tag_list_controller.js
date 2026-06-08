// app/javascript/controllers/tag_list_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["list", "item"];
  static values = { name: String, placeholder: String };

  add() {
    const item = document.createElement("div");
    item.className = "input-group";
    item.dataset.tagListTarget = "item";
    item.innerHTML = `
      <input type="text"
             name="${this.nameValue}"
             class="form-control"
             placeholder="${this.placeholderValue}">
      <button type="button"
              class="btn btn-outline-danger"
              data-action="click->tag-list#remove">
        <i class="bi bi-trash"></i>
      </button>`;
    this.listTarget.appendChild(item);
    item.querySelector("input").focus();
  }

  remove(event) {
    const item = event.currentTarget.closest("[data-tag-list-target='item']");
    if (this.itemTargets.length > 1) {
      item.remove();
    } else {
      item.querySelector("input").value = "";
    }
  }
}
