require "test_helper"

# Every screen builds, and every output its parts declare has an arm in `wire`, unless the screen
# grounds it on purpose (GROUNDED); and no arm names an output nobody declares.
class WiringTest < ActiveSupport::TestCase
  [ Screens::Catalog, Screens::Cart, Screens::Checkout, Screens::Portal ].each do |screen_class|
    test "#{screen_class} wires every output its parts declare, except those left open on purpose" do
      cart = Cart.create!(status: "open")
      assert_equal({ unwired: [], unknown: [] }, ProgrammingParadigms::Drawing.gaps(screen_class.new(cart_id: cart.id)))
    end
  end
end
