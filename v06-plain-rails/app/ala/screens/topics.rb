module Screens
  # The live topics a publishing screen and a listening page agree on (§4.7.4), named once here and
  # passed to both as configuration.
  module Topics
    CATALOG = "catalog"

    def self.payment(cart_id) = "payment_#{cart_id}"
  end
end
