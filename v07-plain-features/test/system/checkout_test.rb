require "application_system_test_case"

class CheckoutSystemTest < ApplicationSystemTestCase
  # Holds a page's stream subscription until the test lets it through, so a broadcast can be sent
  # while the page is up but not yet listening.
  module HeldSubscriptions
    singleton_class.attr_accessor :gate

    def subscribed
      HeldSubscriptions.gate&.pop(timeout: 10)
      super
    end
  end
  Turbo::StreamsChannel.prepend(HeldSubscriptions)

  teardown { HeldSubscriptions.gate&.close }

  def to_payment
    @product = create_product(name: "Widget", amount: 1000, stock: 3)
    visit products_path
    click_on "Add to cart"
    visit cart_path
    click_on "Checkout"
    fill_in "Full name", with: "Ada"
    fill_in "Address", with: "1 Lane"
    fill_in "City", with: "Leeds"
    fill_in "Postal code", with: "12345"
    click_on "Continue to payment"
    assert_text "Ada"
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
  end

  test "address, payment, the payment job, and the live redirect to the success page" do
    to_payment
    click_on "Pay"
    assert_text "Processing payment…"
    perform_enqueued_jobs(only: ProgrammingParadigms::PushLater)
    assert_text "Thanks for your business!", wait: 10
    assert_equal 2, @product.reload.stock
  end

  test "a payment that finishes before the processing step is on the page still reaches success" do
    to_payment
    test = self
    finish_early = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, event|
      test.perform_enqueued_jobs(only: ProgrammingParadigms::PushLater) if event[:controller] == "CheckoutsController" && event[:action] == "show"
    end
    click_on "Pay"
    assert_text "Thanks for your business!", wait: 10
  ensure
    ActiveSupport::Notifications.unsubscribe(finish_early) if finish_early
  end

  test "a payment that fails before a reloaded page is subscribed still shows the failure" do
    FakeGateway.reset([ [ :error, :declined ] ])
    to_payment
    click_on "Pay"
    assert_text "Processing payment…"
    HeldSubscriptions.gate = Queue.new
    refresh
    assert_text "Processing payment…"
    perform_enqueued_jobs(only: ProgrammingParadigms::PushLater)
    HeldSubscriptions.gate.close
    assert_text "Payment failed.", wait: 10
    assert_button "Try again"
  end
end
