ENV["RAILS_ENV"] ||= "test"
require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
end

require_relative "../config/environment"
require "rails/test_help"
require "turbo/broadcastable/test_helper"
require_relative "support/fake_payment_gateway"

Rails.configuration.x.store.payment_gateway = "FakePaymentGateway"

module ActiveSupport
  class TestCase
    # Forked workers hang against this machine's Postgres.
    parallelize(workers: 1)

    fixtures :all

    include Turbo::Broadcastable::TestHelper

    setup { FakePaymentGateway.reset }
  end
end

class ActionDispatch::IntegrationTest
  def add_to_cart(product)
    post cart_items_path, params: { product_id: product.id }
    Cart.find(session[:cart_id]).cart_items.find_by!(product:)
  end

  def current_cart
    Cart.find(session[:cart_id])
  end

  def assert_stream_text(target, text)
    stream = Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream[target='#{target}']")
    assert stream, "no turbo-stream targeting #{target}"
    text.is_a?(Regexp) ? assert_match(text, stream.text) : assert_equal(text, stream.text.strip)
  end

  def turbo_stream
    { "Accept" => "text/vnd.turbo-stream.html, text/html" }
  end
end
