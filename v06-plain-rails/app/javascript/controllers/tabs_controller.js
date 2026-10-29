import { Controller } from "@hotwired/stimulus"

// Shows the pane whose name matches the clicked tab; the choice lives only in the browser, so a page
// refresh that morphs the page keeps it.
const CHOICE = ["hidden", "aria-selected"]

export default class extends Controller {
  static targets = ["tab", "pane"]

  connect() {
    this.keep = (event) => [...this.tabTargets, ...this.paneTargets].includes(event.target) && CHOICE.includes(event.detail.attributeName) && event.preventDefault()
    document.addEventListener("turbo:before-morph-attribute", this.keep)
  }

  disconnect() {
    document.removeEventListener("turbo:before-morph-attribute", this.keep)
  }

  show(event) {
    const name = event.currentTarget.dataset.name
    this.tabTargets.forEach(tab => tab.setAttribute("aria-selected", tab.dataset.name === name))
    this.paneTargets.forEach(pane => pane.hidden = pane.dataset.name !== name)
  }
}
