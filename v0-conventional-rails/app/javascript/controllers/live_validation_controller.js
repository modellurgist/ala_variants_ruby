import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { url: String }

  validate() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.submit(), 200)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  async submit() {
    const body = new FormData(this.element)
    body.delete("_method")
    const response = await fetch(this.urlValue, {
      method: "POST",
      body,
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      }
    })
    Turbo.renderStreamMessage(await response.text())
  }
}
