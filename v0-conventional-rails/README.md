# V0: Conventional Rails

The conventional baseline. It implements `../../ala_lab/docs/requirements-storefront-and-portal.md`
(R1.1–R8.2) the way the Rails guides teach, for comparison with the ALA variants (V01–V07). There
are no ports, wiring, or compositions. The app uses fat models, skinny RESTful controllers,
`.turbo_stream.erb` responses, `Turbo::Broadcastable` callbacks, Active Job, and a few small
Stimulus controllers.

Stack (same as V07): Ruby 4.0.7, Rails 8.1.4, Postgres, propshaft, importmap, turbo-rails,
stimulus-rails, tailwindcss-rails, solid_*, and capybara + cuprite for system tests. The only gem
added beyond V07 is `simplecov` (test group).

## Run it

```bash
bin/rails db:prepare db:seed   # Postgres at localhost, postgres/postgres
bin/dev                        # http://localhost:3000
```

## Tests

```bash
bin/rails test test/models        # model tests
bin/rails test test/jobs          # job tests
bin/rails test test/controllers   # integration (controller) tests
bin/rails test test/system        # Cuprite browser tests (headless Chrome)
bin/rails test                    # everything except system
bin/rails test:all                # everything
```

SimpleCov writes `coverage/index.html` after each run. It measures line and branch coverage of
Ruby under `app/` only, so ERB views and JavaScript are not counted.

## Where things are

- `app/models`: `Product`, `Cart` (status and kind enums), `CartItem` (quantity, gift wrap,
  saved-for-later, soft-removal `removed_at`), `WishlistItem`, `Checkout` (address and payment
  status), `Order`/`OrderItem`, the `CartTotals` pricing PORO, `ShippingMethod`, `PromoCode`, and
  `LocalPaymentGateway`.
- `config/store.yml` (read through `config.x.store`) holds the calibration: shipping methods, promo
  codes, gift wrap, volume tiers, undo window, low-stock threshold, and payment gateway class. Tests
  override values on `Rails.configuration.x.store`.
- `app/controllers/concerns/current_cart.rb` keeps the session carts under `session[:cart_id]` and
  `session[:portal_cart_id]`.
- `app/jobs`: `FinalizeRemovalJob` (undo window expiry) and `PaymentJob` (async payment).
- `app/javascript/controllers`: `live_validation`, `tabs`, and `auto_submit`, plus a custom
  `redirect` Turbo Stream action in `application.js`.

## Requirement → test traceability

| R | Tests (file › test) |
|---|---|
| R1.1 | controllers/carts_controller_test › first visit creates an open cart…; a completed cart is replaced… |
| R1.2 | controllers/carts_controller_test › storefront cart and portal draft are separate… |
| R1.3 | models/cart_test › a new cart is open…; status is open, completed, or abandoned; placing a storefront order… completes the cart |
| R1.4 | controllers/carts_controller_test › cart contents persist across page loads |
| R2.1 | controllers/products_controller_test › index lists every product… |
| R2.2 | controllers/products_controller_test › new, edit, and show/edit render the form in the modal frame; creating…; invalid product…; updating…; destroying…; live validation (new and existing); models/product_test › requires a name and an amount; system/products_test › creating a product in the modal validates live…; editing from the show page and deleting… |
| R2.3 | controllers/products_controller_test › shows one product |
| R2.4 | controllers/cart_items_controller_test › add to cart persists a line and flashes; add to cart from the list flashes in place |
| R2.5 | models/product_test › creating…/updating… replaces its row in every product list…; system/products_test › products saved or restocked elsewhere update every open list… |
| R2.6 | models/product_test › updating a product…; system/products_test › products saved or restocked elsewhere…; system/checkouts_test › …stock drops live elsewhere |
| R3.1 | controllers/carts_controller_test › shows each item with name, thumbnail…; models/product_test › stock status is in stock, low stock at 5 or fewer… |
| R3.2 | controllers/cart_items_controller_test › steppers change the quantity…; the decrement is disabled at 1…; models/cart_item_test › quantity never drops below 1; system/carts_test › steppers… |
| R3.3 | controllers/cart_items_controller_test › removing an item drops the row, recomputes totals, and shows the undo banner |
| R3.4 | controllers/cart_items_controller_test › gift wrap toggles on and off…; models/cart_item_test › removing… clears gift wrap… |
| R3.5 | controllers/carts_controller_test › an empty cart says so and disables checkout; system/checkouts_test › checkout is disabled for an empty cart |
| R3.6 | models/cart_test › adding a product creates a line, and adding it again increments…; controllers/cart_items_controller_test › adding the same product again… |
| R3.7 | controllers/carts_controller_test › tabs show their counts…; system/carts_test › tabs switch in the browser… |
| R3.8 | controllers/cart_items_controller_test › save for later moves the item…; models/cart_item_test › save for later and move to cart; system/carts_test › tabs switch… |
| R3.9 | controllers/cart_items_controller_test › wishlist toggles the product and marks the row; controllers/wishlist_items_controller_test (all); system/carts_test › wishlist from a row… |
| R3.10 | controllers/carts_controller_test › the summary shows discount, gift wrap, shipping label, and total |
| R3.11 | models/cart_totals_test (all) |
| R3.12 | controllers/pricing_controllers_test › a valid promo code…; an invalid promo code…; models/cart_test › a valid promo code is stored…; system/carts_test › promo codes and shipping choices… |
| R3.13 | models/cart_totals_test › an empty cart… ships free; standard shipping is free from 5000…; controllers/pricing_controllers_test › choosing a shipping method… |
| R3.14 | models/product_test › a stock change updates the product's row in every open cart…; system/carts_test › a stock change elsewhere updates the cart row live |
| R4.1 | models/cart_item_test › removing… schedules finalising after the undo window; controllers/cart_items_controller_test › removing an item…; controllers/carts_controller_test › a pending removal still offers undo after a reload |
| R4.2 | controllers/cart_undos_controller_test › undo restores the removed item…; system/carts_test › remove offers undo… |
| R4.3 | jobs/finalize_removal_job_test (all); system/carts_test › when the undo window elapses… |
| R4.4 | models/cart_item_test › a second removal makes the first one final; controllers/cart_undos_controller_test › only the most recent removal is undoable |
| R5.1 | controllers/checkouts_controller_test › starting checkout with an empty cart…; starting checkout goes to the Address step |
| R5.2 | controllers/checkouts_controller_test › the address needs every field…; live validation of the address; models/checkout_test › requires every address field; system/checkouts_test › address with live validation… |
| R5.3 | controllers/checkouts_controller_test › payment shows the address summary, total, Edit address, and Pay |
| R5.4 | controllers/checkouts_controller_test › pay starts the payment in the background…; pay from the page swaps the panel…; pay with an item short of stock…; pay with an empty cart…; system/checkouts_test › address with live validation, payment processing… |
| R5.5 | models/checkout_test › a successful payment…; a failed payment…; controllers/checkouts_controller_test › a successful payment completes the cart…; a failed payment shows the failure and a retry…; system/checkouts_test › a failed payment offers a retry… |
| R5.6 | controllers/checkouts_controller_test › a forward jump to Payment without an address is ignored…; system/checkouts_test › browser back returns to the previous step… |
| R5.7 | models/checkout_test › opens a gateway session…; the gateway is configurable…; models/local_payment_gateway_test (all) |
| R6.1 | controllers/portals_controller_test › the order step lists the catalog…; adding sets the requested quantity… |
| R6.2 | controllers/portals_controller_test › lines show name, stock status, quantity, and line total… |
| R6.3 | controllers/portals_controller_test › removing a line arms the undo banner…; system/portals_test › build an order… |
| R6.4 | models/cart_totals_test › portal carts reprice by volume tier…; controllers/portals_controller_test › volume pricing reprices across tier boundaries |
| R6.5 | controllers/portals_controller_test › shipping methods as in the storefront; no promo or gift wrap |
| R6.6 | controllers/portals_controller_test › review with an empty order…; review shows the total…; the purchase order number is live-validated; models/order_test › portal orders need a PO- number… |
| R6.7 | controllers/portals_controller_test › submitting with a valid PO…; …invalid PO…; …empty order; models/cart_test › a portal order needs a valid PO… |
| R6.8 | models/product_test › a stock change updates… portal draft…; system/portals_test › stock changes update the catalog row and the affected order line live |
| R6.9 | controllers/portals_controller_test › review with an empty order… a forward jump to Submitted is ignored; system/portals_test › build an order… (Edit lines, then browser back) |
| R8.1 | every `assert_turbo_stream`/`assert_turbo_stream_broadcasts` test above; system tests for live updates |
| R8.2 | models/cart_test › …lives in Postgres; all model tests persist through Active Record on Postgres |

## Judgement calls and deviations

- **Undo expiry.** `CartItem#remove!` soft-removes the item and enqueues
  `FinalizeRemovalJob.set(wait: undo_window)`. The job destroys the item and broadcasts the banner
  away, unless the item was restored or removed again since. The browser system test performs the
  job by hand rather than waiting 5 s.
- **Payment.** The gateway interface is `checkout(line_items:, success_url:)`. It returns the URL
  to send the shopper to, or nil on failure. The default `LocalPaymentGateway` settles in-process
  (as built). On success the job broadcasts a custom `redirect` Turbo Stream action. Pay swaps the
  payment panel in place instead of redirecting, so the page's stream subscription stays up and
  the result can't be missed. Reloading the payment URL after the cart has completed redirects to
  the success page.
- **Success page.** It shows the order reference as well as the thanks (open question 1).
- **Portal submission.** It does not decrement stock, following the requirement text (open
  question 3). The portal has no promo codes or gift wrap (R6.5 as built).
- **`abandoned`.** The status exists but nothing sets it (open question 2).
- **Pricing.** Standard shipping is free when the subtotal is ≥ 5000, as in V07. Gift wrap is
  charged per wrapped line, not per unit. Discounts round down to whole cents.
- **Messages.** Flash and error strings are inline in controllers and models, not in I18n.
- **Live validation.** It posts the whole form and shows every current error, including errors for
  fields not touched yet.
- **Known Turbo limitation.** A broadcast sent while a page is between stream subscriptions (for
  example mid-navigation) is lost. Turbo does not replay missed broadcasts.
