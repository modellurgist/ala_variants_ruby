import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The browser half of ProgrammingParadigms::ChangeFeed. A fact arrives on the page's stream as a
// `change_feed` action; a fact of a kind this page listens to is posted to the page's own
// refresh URL, and what the page's composition answers is rendered.
Turbo.StreamActions.change_feed = function () {
  document.dispatchEvent(new CustomEvent("change-feed:fact", { detail: { kind: this.getAttribute("kind"), fact: this.getAttribute("fact") } }))
}

export default class extends Controller {
  static values = { kinds: Array, url: String }

  connect() {
    this.listener = (event) => this.refresh(event.detail)
    document.addEventListener("change-feed:fact", this.listener)
  }

  disconnect() {
    document.removeEventListener("change-feed:fact", this.listener)
  }

  async refresh({ kind, fact }) {
    if (!this.kindsValue.includes(kind)) return
    const body = new FormData()
    body.append("kind", kind)
    body.append("fact", fact)
    const response = await fetch(this.urlValue, {
      method: "POST",
      body,
      headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content }
    })
    if (response.ok) Turbo.renderStreamMessage(await response.text())
  }
}
