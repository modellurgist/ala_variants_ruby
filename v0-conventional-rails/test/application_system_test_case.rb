require "test_helper"
require "capybara/cuprite"

# Broadcasts must reach the browser, so system tests swap Action Cable's test adapter for the in-process
# async one. Jobs stay on the test adapter; tests perform them where the scenario needs it.
ActionCable.server.config.cable = { "adapter" => "async" }
ActionCable.server.instance_variable_set(:@pubsub, nil)
Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :cuprite, screen_size: [ 1280, 900 ], options: { js_errors: true, headless: true, process_timeout: 20 }

  # A broadcast sent before the page has subscribed is lost, so wait for every stream source.
  def wait_for_streams
    assert_no_selector "turbo-cable-stream-source:not([connected])", visible: :all
  end

  def add_to_cart(product)
    visit products_path
    within("#product_#{product.id}") { click_on "Add to cart" }
    assert_text "Added to cart"
  end
end
