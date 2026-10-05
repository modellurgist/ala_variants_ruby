import { Controller } from "@hotwired/stimulus"

// Submits the form it is on when asked, so a choice applies without a button.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
