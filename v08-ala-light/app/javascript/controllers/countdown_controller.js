import { Controller } from "@hotwired/stimulus"

// Submits its form target after a delay: the undo offer expiring by itself.
export default class extends Controller {
  static targets = ["form"]
  static values = { after: Number }

  connect() {
    this.timeout = setTimeout(() => this.formTarget.requestSubmit(), this.afterValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
