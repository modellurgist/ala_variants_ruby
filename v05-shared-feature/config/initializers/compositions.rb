# The compositions that outlive a request, one registry per kept screen, named so a job can reach
# them. Rebuilt on reload in development so edited classes take.
Rails.application.config.to_prepare do
  ProgrammingParadigms::LongLived.register(:cart_screens,
    build: ->(cart_id) { Screens::Cart.new(cart_id:) }, version: ->(cart_id) { Cart.version_of(cart_id) },
    reload: :reload, begin: :begin, capacity: 1000)
  ProgrammingParadigms::LongLived.register(:checkout_screens,
    build: ->(cart_id) { Screens::Checkout.new(cart_id:) }, version: ->(cart_id) { Cart.version_of(cart_id) },
    reload: :reload, begin: :begin, capacity: 1000)
end
