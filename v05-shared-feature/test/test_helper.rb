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
    setup { ProgrammingParadigms::LongLived.clear_all }

    def create_product(name: "Widget", amount: 1000, stock: 10, description: "A fine product", thumbnail: "w.png")
      Product.create!(name:, amount:, stock:, description:, thumbnail:)
    end
  end
end

# The wiring as it ran: after the suite, every wire of every screen (and of the features inside) must
# have carried something at least once, and docs/diagrams/running/ draws each screen with the wires
# that did solid and the rest dotted; only a whole run redraws them. A wire listed here is one no test reaches yet: the suite's debt,
# not the design's.
Foundation::Trace.enable
UNEXERCISED = %w[].freeze
Minitest.after_run do
  screens = [ Screens::Catalog, Screens::Cart, Screens::Checkout, Screens::Portal ]
  whole_suite = Dir["test/{ala,controllers}/*_test.rb"].all? { $LOADED_FEATURES.include?(File.expand_path(_1)) }
  FileUtils.mkdir_p("docs/diagrams/running") if whole_suite
  unfired = []
  Cart.transaction do
    cart = Cart.create!(status: "open")
    screens.each do |screen|
      composition = screen.new(cart_id: cart.id)
      File.write("docs/diagrams/running/#{screen.name.demodulize.underscore}.md", "# #{screen.name}, as it ran\n\n```mermaid\n#{ProgrammingParadigms::Drawing.running(composition)}```\n") if whole_suite
      unfired.concat(ProgrammingParadigms::Drawing.unfired(composition).map { "#{screen.name}: #{_1}" })
    end
    raise ActiveRecord::Rollback
  end
  debt = unfired - UNEXERCISED
  puts "\nWiring as it ran: #{Foundation::Trace.hops.size} distinct hops; #{unfired.size} wires never carried anything#{" (#{UNEXERCISED.size} listed as unexercised)" if UNEXERCISED.any?}#{" (a partial run: not enforced)" unless whole_suite}"
  unless debt.empty? || !whole_suite
    puts debt.map { "  #{_1}" }
    $stdout.flush
    Process.exit!(1)
  end
end
