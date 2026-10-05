ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "turbo/broadcastable/test_helper"
require_relative "support/fake_gateway"
Rails.configuration.x.payment_gateway = "FakeGateway"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    include Turbo::Broadcastable::TestHelper

    def create_product(name: "Widget", amount: 1000, stock: 10, description: "A fine product", thumbnail: "w.png")
      Product.create!(name:, amount:, stock:, description:, thumbnail:)
    end
  end
end
