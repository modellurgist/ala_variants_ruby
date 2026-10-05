import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Validates a form as the shopper types: posts it to the validate URL and renders the Turbo Stream that
// comes back (the form, with its errors), keeping the focus where it was.
export default class extends Controller {
  static values = { url: String }

  async check(event) {
    const field = event.target.name
    const caret = event.target.selectionEnd
    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content },
      body: new FormData(this.element)
    })
    Turbo.renderStreamMessage(await response.text())
    requestAnimationFrame(() => {
      const again = document.querySelector(`[name="${CSS.escape(field)}"]`)
      if (again) { again.focus(); if (caret != null && again.setSelectionRange) again.setSelectionRange(caret, caret) }
    })
  }
}
