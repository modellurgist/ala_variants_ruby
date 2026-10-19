require "test_helper"

# Every screen builds, and every output of its parts is either wired or deliberately left open. An
# output listed here is one the screen has no use for (a load's rows on a screen that doesn't show
# them, say); anything else unwired is a missing wire.
class WiringTest < ActiveSupport::TestCase
  GROUNDED = {
    Screens::Catalog => [],
    Screens::Cart => [],
    Screens::Checkout => %w[items.added items.found lines.changed lines.adding lines.rows lines.row_added lines.row_changed lines.row_removed lines.removed lines.saved lines.line pricing.promo_applied pricing.promo_rejected],
    Screens::Portal => %w[order.row_added order.row_changed order.row_removed order.saved order.line catalog.record catalog.form catalog.created catalog.updated catalog.deleted]
  }.freeze

  GROUNDED.each do |screen_class, grounded|
    test "#{screen_class} wires every port its parts declare, except those left open on purpose" do
      cart = Cart.create!(status: "open")
      screen = screen_class.new(cart_id: cart.id)
      unwired = screen.parts.flat_map { |name, part| part.unwired_outputs.map { "#{name}.#{_1}" } }
      assert_equal grounded.sort, unwired.sort
      assert_empty screen.unwired_outputs
      # a feature's own parts are wired inside it, every output
      screen.parts.each_value { |part| part.parts.each_value { assert_empty _1.unwired_outputs } }
    end
  end
end
