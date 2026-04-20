// app/javascript/controllers/variant_filters_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  submit(event) {
    event.target.closest("form").requestSubmit();
  }

  debounceSubmit(event) {
    clearTimeout(this._debounce);
    this._debounce = setTimeout(() => {
      event.target.closest("form").requestSubmit();
    }, 350);
  }
}
