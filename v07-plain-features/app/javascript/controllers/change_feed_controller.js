import { Controller } from "@hotwired/stimulus"
import { Turbo, cable } from "@hotwired/turbo-rails"

// The browser end of the ChangeFeed paradigm: subscribes to the page's signed topic and posts each
// fact of a kind the page listens to to the page's live URL, which answers with the page's patches.
// Marks its element `connected` while subscribed, as Turbo's stream source does.
export default class extends Controller {
  static values = { topic: String, kinds: Array, url: String }

  async connect() {
    this.subscription = await cable.subscribeTo({ channel: "ProgrammingParadigms::ChangeFeed::Channel", topic: this.topicValue }, {
      received: (fact) => { if (this.kindsValue.includes(fact.kind)) this.deliver(fact) },
      connected: () => this.element.setAttribute("connected", ""),
      disconnected: () => this.element.removeAttribute("connected"),
    })
    if (!this.element.isConnected) this.subscription.unsubscribe()
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  async deliver(fact) {
    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: { Accept: "text/vnd.turbo-stream.html", "Content-Type": "application/json",
                 "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content },
      body: JSON.stringify({ fact }),
    })
    // a fact answered after the page was left would patch the next one
    if (response.ok && this.element.isConnected) Turbo.renderStreamMessage(await response.text())
  }
}
