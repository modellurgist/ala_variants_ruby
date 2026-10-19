import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    const name = event.currentTarget.dataset.tab
    this.tabTargets.forEach(tab => tab.setAttribute("aria-selected", tab.dataset.tab === name))
    this.panelTargets.forEach(panel => panel.hidden = panel.dataset.tab !== name)
  }
}
