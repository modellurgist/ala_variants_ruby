# The compositions that outlive a request. Rebuilt on reload in development so edited classes take.
Rails.application.config.to_prepare do
  Rails.configuration.x.cart_screens = ProgrammingParadigms::LongLived.new(
    build: ->(cart_id) { Screens::Cart.new(cart_id:) },
    version: ->(cart_id) { Cart.version_of(cart_id) },
    reload: :reload, begin: :begin, capacity: 1000)
end
