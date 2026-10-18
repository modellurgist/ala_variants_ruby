ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "turbo/broadcastable/test_helper"
require_relative "support/fake_gateway"
Rails.configuration.x.payment_gateway = "FakeGateway"

module ActiveSupport
  class TestCase
    # one process: the forked workers hang on this machine's Postgres setup
    parallelize(workers: 1)
    include Turbo::Broadcastable::TestHelper

    def create_product(name: "Widget", amount: 1000, stock: 10, description: "A fine product", thumbnail: "w.png")
      Product.create!(name:, amount:, stock:, description:, thumbnail:)
    end
  end
end

# The wiring as it ran: after the whole suite, every output a screen's parts declare must have been
# routed at least once (less what the screen grounds), and docs/diagrams/running/ draws each screen
# from the hops. A partial run reports and never fails.
Foundation::Trace.enable
Minitest.after_run do
  screens = [ Screens::Catalog, Screens::Cart, Screens::Checkout, Screens::Portal ]
  FileUtils.mkdir_p("docs/diagrams/running")
  unrouted = []
  Cart.transaction do
    cart = Cart.create!(status: "open")
    screens.each do |screen|
      composition = screen.new(cart_id: cart.id)
      File.write("docs/diagrams/running/#{screen.name.demodulize.underscore}.md", "# #{screen.name}, as it ran\n\n```mermaid\n#{ProgrammingParadigms::Drawing.running(composition)}```\n")
      unrouted.concat(ProgrammingParadigms::Drawing.unrouted(composition).map { "#{screen.name}: #{_1}" })
    end
    raise ActiveRecord::Rollback
  end
  whole_suite = Dir["test/{ala,controllers}/*_test.rb"].all? { $LOADED_FEATURES.include?(File.expand_path(_1)) }
  puts "\nWiring as it ran: #{unrouted.size} declared outputs never routed#{" (a partial run: not enforced)" unless whole_suite}"
  unless unrouted.empty? || !whole_suite
    puts unrouted.map { "  #{_1}" }
    $stdout.flush
    Process.exit!(1)
  end
end
