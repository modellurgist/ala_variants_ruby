import { Controller } from "@hotwired/stimulus"

// Removes its element after a delay: a notice that goes away by itself.
export default class extends Controller {
  static values = { after: Number }

  connect() {
    this.timeout = setTimeout(() => this.element.remove(), this.afterValue || 2500)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
