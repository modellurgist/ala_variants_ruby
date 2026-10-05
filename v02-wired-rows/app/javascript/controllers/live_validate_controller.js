import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Validates a form as the shopper types: posts it to the validate URL and renders the Turbo Stream that
// comes back (the form, with its errors), a pause after the last keystroke. The reply replaces the
// whole form, so the field being typed in keeps what was typed meanwhile, and a reply that arrives
// after a newer one is dropped.
export default class extends Controller {
  static values = { url: String, delay: { type: Number, default: 250 } }

  check(event) {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.validate(event.target.name), this.delayValue)
  }

  // Submitting makes any pending or in-flight validation moot.
  cancel() {
    clearTimeout(this.timer)
    this.sequence = (this.sequence || 0) + 1
  }

  async validate(field) {
    const sequence = (this.sequence = (this.sequence || 0) + 1)
    const body = new FormData(this.element)
    body.delete("_method")
    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content },
      body
    })
    const html = await response.text()
    if (sequence !== this.sequence) return
    const live = document.querySelector(`[name="${CSS.escape(field)}"]`)
    const typed = live?.value
    const caret = live?.selectionEnd
    Turbo.renderStreamMessage(html)
    requestAnimationFrame(() => {
      const again = document.querySelector(`[name="${CSS.escape(field)}"]`)
      if (!again) return
      if (typed != null) again.value = typed
      again.focus()
      if (caret != null && again.setSelectionRange) again.setSelectionRange(caret, caret)
    })
  }
}
