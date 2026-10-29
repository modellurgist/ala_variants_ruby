import { Controller } from "@hotwired/stimulus"
import { Turbo, cable } from "@hotwired/turbo-rails"

// The page's end of ProgrammingParadigms::ChangeFeed: subscribes for the facts its feed hears and
// refreshes the page (a morph) when one arrives. A refresh waits while Turbo is busy, since a visit or
// submission under way may answer from before the fact. During its own refresh it keeps what the viewer
// has typed and any element with an id marked data-change-feed-keep (an open modal, the flash); an
// element without an id could be paired with a different one and swallow it.
const RETRY_ON = ["turbo:load", "turbo:submit-end", "turbo:frame-load"]

export default class extends Controller {
  static values = { topic: String, kinds: Array, match: Object, catchUp: Boolean }

  async connect() {
    const attempt = this.attempt = {}
    this.retry = () => setTimeout(() => this.refresh())
    this.keepTyped = (event) => this.refreshing() && event.detail.attributeName === "value" && edited(event.target) && event.preventDefault()
    this.keepMarked = (event) => this.refreshing() && event.target.id && event.target.hasAttribute("data-change-feed-keep") && event.preventDefault()
    RETRY_ON.forEach((name) => document.addEventListener(name, this.retry))
    document.addEventListener("turbo:before-morph-attribute", this.keepTyped)
    document.addEventListener("turbo:before-morph-element", this.keepMarked)
    const subscription = await cable.subscribeTo(
      { channel: "ProgrammingParadigms::ChangeFeed::Channel", signed_topic: this.topicValue, kinds: this.kindsValue, match: this.matchValue },
      {
        received: () => this.stale(),
        connected: () => { this.element.setAttribute("connected", ""); if (this.catchUpValue) this.stale() },
        disconnected: () => this.element.removeAttribute("connected")
      }
    )
    if (this.attempt === attempt) this.subscription = subscription
    else subscription.unsubscribe()
  }

  disconnect() {
    RETRY_ON.forEach((name) => document.removeEventListener(name, this.retry))
    document.removeEventListener("turbo:before-morph-attribute", this.keepTyped)
    document.removeEventListener("turbo:before-morph-element", this.keepMarked)
    this.subscription?.unsubscribe()
    this.subscription = this.attempt = null
  }

  stale() {
    this.isStale = true
    this.refresh()
  }

  refresh() {
    if (!this.isStale || document.querySelector("[aria-busy]")) return
    this.isStale = false
    Turbo.visit(window.location.href, { action: "replace" })
    this.visit = Turbo.session.navigator.currentVisit
  }

  // Turbo starts a visit synchronously; one started after ours (a form's redirect) replaces it.
  refreshing() {
    return this.visit && this.visit === Turbo.session.navigator.currentVisit
  }
}

function edited(element) {
  return "defaultValue" in element && element.value !== element.defaultValue
}
