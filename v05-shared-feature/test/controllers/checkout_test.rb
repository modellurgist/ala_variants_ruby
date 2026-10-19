require "test_helper"

# Acceptance tests for the checkout requirements (R5), ported from the Elixir variants.
class CheckoutTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { FakeGateway.reset }

  def open_cart
    get cart_path
    @a = create_product(name: "Widget", amount: 1000, stock: 10)
    @b = create_product(name: "Gadget", amount: 2500, stock: 5)
    CartItem.add(session[:cart_id], @a.id)
    CartItem.add(session[:cart_id], @b.id)
  end

  def address = { checkout: { name: "Ada", line1: "1 Ave", city: "London", postal_code: "12345" } }

  test "an empty cart can't start checkout" do
    get cart_path
    post cart_checkout_path
    assert_redirected_to cart_path
    follow_redirect!
    assert_select "#flash", /Your cart is empty/
  end

  test "address → payment → pay → order settled, stock taken and broadcast, success page" do
    open_cart
    post cart_checkout_path
    assert_redirected_to cart_checkout_path
    follow_redirect!
    assert_select "label", "Full name"

    patch address_cart_checkout_path, params: { checkout: { name: "", line1: "", city: "", postal_code: "x" } }
    assert_response :unprocessable_content
    assert_select "body", /can&#39;t be blank|must be 4–10 digits/

    patch address_cart_checkout_path, params: address
    assert_redirected_to cart_checkout_step_path(:payment)
    follow_redirect!
    assert_select "form[action=?] button", pay_cart_checkout_path, /Pay/
    assert_select "body", /\$40\.99/

    cart_id = session[:cart_id]
    assert_enqueued_with(job: ProgrammingParadigms::PushLater) { post pay_cart_checkout_path }
    assert_redirected_to cart_checkout_step_path(:payment)
    follow_redirect!
    assert_select "body", /Processing payment/

    assert_turbo_stream_broadcasts(Screens::Catalog::STREAM, count: 2) do
      assert_turbo_stream_broadcasts(Screens::Checkout.stream(cart_id), count: 1) { perform_enqueued_jobs }
    end
    assert_equal [ { amount: 3500, currency: "usd", metadata: { "cart_id" => cart_id } } ], FakeGateway.charges
    # the job delivered `charge` into the kept composition, not a rebuilt one
    kept = ProgrammingParadigms::LongLived.named(:checkout_screens)
    assert_equal [ true, 1 ], [ kept.with(cart_id) { _1.done.present? }, kept.size ]
    assert_equal "completed", Cart.find(cart_id).status
    assert Order.exists?(cart_id:)
    assert_equal [ 9, 4 ], [ @a.reload.stock, @b.reload.stock ]

    get cart_checkout_step_path(:payment)
    assert_redirected_to cart_success_path
    follow_redirect!
    assert_select "h1", "You did it!"
  end

  test "pay with an item short of stock is blocked" do
    open_cart
    post cart_checkout_path
    patch address_cart_checkout_path, params: address
    @b.update!(stock: 0)
    post pay_cart_checkout_path
    follow_redirect!
    assert_select "#flash", /Some items are out of stock/
    assert_enqueued_jobs 0
  end

  test "a failed payment offers a retry that pays again" do
    FakeGateway.reset([ [ :error, :declined ], [ :ok, "chg_retry" ] ])
    open_cart
    post cart_checkout_path
    patch address_cart_checkout_path, params: address
    post pay_cart_checkout_path
    perform_enqueued_jobs
    get cart_checkout_step_path(:payment)
    assert_select "body", /Payment failed\./
    assert_select "form[action=?] button", pay_cart_checkout_path, "Try again"

    post pay_cart_checkout_path
    perform_enqueued_jobs
    get cart_checkout_step_path(:payment)
    assert_redirected_to cart_success_path
    assert_equal 2, FakeGateway.charges.size
  end

  test "a page waiting on the payment can ask for the outcome: nothing while processing, then the outcome" do
    FakeGateway.reset([ [ :error, :declined ] ])
    open_cart
    post cart_checkout_path
    patch address_cart_checkout_path, params: address
    post pay_cart_checkout_path
    get status_cart_checkout_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :no_content

    perform_enqueued_jobs
    get status_cart_checkout_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_match(/<turbo-stream action="replace" target="checkout_status">/, response.body)
    assert_match(/Payment failed\./, response.body)
  end

  # A job process keeps its own table: it builds a checkout of its own, delivers there, and only the
  # stamp tells the web process's kept checkout that the step moved.
  def pay_in_another_process
    job = enqueued_jobs.shift
    _registry, key, port, payload = ActiveJob::Arguments.deserialize(job[:args])
    other = ProgrammingParadigms::LongLived.new(build: ->(id) { Screens::Checkout.new(cart_id: id) }, version: ->(id) { Cart.version_of(id) },
                                                reload: :reload, begin: :begin, capacity: 1)
    other.with(key) { _1.input_port(port.to_sym).push(payload) }
  end

  def paying
    open_cart
    post cart_checkout_path
    patch address_cart_checkout_path, params: address
    post pay_cart_checkout_path
    get status_cart_checkout_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :no_content
  end

  test "a payment settled by a job in another process reaches the kept checkout" do
    paying
    pay_in_another_process
    assert_equal 1, ProgrammingParadigms::LongLived.named(:checkout_screens).size
    get status_cart_checkout_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :ok
    assert_match(/<turbo-stream action="replace" target="checkout_status">/, response.body)
    get cart_checkout_step_path(:payment)
    assert_redirected_to cart_success_path
  end

  test "a payment declined in another process reaches the kept checkout, and the retry pays" do
    FakeGateway.reset([ [ :error, :declined ], [ :ok, "chg_retry" ] ])
    paying
    pay_in_another_process
    get status_cart_checkout_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_match(/Payment failed\./, response.body)
    get cart_checkout_step_path(:payment)
    assert_select "form[action=?] button", pay_cart_checkout_path, "Try again"

    post pay_cart_checkout_path
    pay_in_another_process
    get cart_checkout_step_path(:payment)
    assert_redirected_to cart_success_path
  end

  test "browser back returns to the address step; a forward URL jump is ignored; a reload lands on the step" do
    open_cart
    post cart_checkout_path
    get cart_checkout_step_path(:payment)
    assert_select "label", "Full name"

    patch address_cart_checkout_path, params: address
    get cart_checkout_step_path(:payment)
    assert_select "body", /Edit address/
    get cart_checkout_step_path(:payment)
    assert_select "body", /Edit address/

    get cart_checkout_path
    assert_select "label", "Full name"
    assert_select "input[value=?]", "Ada"
    get cart_checkout_step_path(:payment)
    assert_select "label", "Full name"
    assert_select "body", { text: /Edit address/, count: 0 }
  end

  test "the address validates live" do
    open_cart
    post cart_checkout_path
    post validate_cart_checkout_path, params: { checkout: { name: "", postal_code: "12" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_match(/must be 4–10 digits/, response.body)
  end
end
