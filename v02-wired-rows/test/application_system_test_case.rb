require "test_helper"
require "capybara/cuprite"

# Browser tests through Cuprite (Chrome over DevTools). Broadcasts must reach the browser, so this
# process runs Action Cable's in-process async adapter instead of the test adapter the integration
# tests assert on. Jobs stay on the test adapter and are performed by hand where a test needs them.
ActionCable.server.config.cable = { "adapter" => "async" }
ActionCable.server.instance_variable_set(:@pubsub, nil)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :cuprite, screen_size: [ 1200, 900 ], options: { js_errors: true, headless: true, process_timeout: 20 }
  parallelize(workers: 1)

  setup { FakeGateway.reset }
end
