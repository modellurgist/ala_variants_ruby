import { Controller } from "@hotwired/stimulus"

// Shows the pane whose name matches the clicked tab; the choice lives only in the browser.
export default class extends Controller {
  static targets = ["tab", "pane"]

  show(event) {
    const name = event.currentTarget.dataset.name
    this.tabTargets.forEach(tab => tab.setAttribute("aria-selected", tab.dataset.name === name))
    this.paneTargets.forEach(pane => pane.hidden = pane.dataset.name !== name)
  }
}
