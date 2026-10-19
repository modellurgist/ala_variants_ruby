// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"

// Lets a background job send the shopper on (e.g. to the success page once payment settles).
Turbo.StreamActions.redirect = function () {
  Turbo.visit(this.getAttribute("url"))
}
