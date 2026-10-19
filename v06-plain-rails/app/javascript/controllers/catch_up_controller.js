import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Asks the server for an outcome while the page waits on a live update. A broadcast sent before this
// element was on the page, or before the page's stream was subscribed, never arrives; so it asks once
// on appearing (a Pay that morphed the page keeps its subscription) and again each time a stream
// subscribes (a fresh load or a reconnect). The server answers only an outcome, never "still waiting".
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.observer = new MutationObserver((changes) => {
      if (changes.some((change) => change.target.hasAttribute("connected"))) this.ask()
    })
    document.querySelectorAll("turbo-cable-stream-source").forEach((source) =>
      this.observer.observe(source, { attributeFilter: ["connected"] })
    )
    this.ask()
  }

  disconnect() {
    this.observer.disconnect()
  }

  async ask() {
    const response = await fetch(this.urlValue, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    if (response.status === 200) Turbo.renderStreamMessage(await response.text())
  }
}
