require "test_helper"

# Exercised on a checkout record only for its `step` column; the table is the test's own.
class PersistedStepsTest < ActiveSupport::TestCase
  TABLE = [ [ :address, :next, :payment ], [ :payment, :next, :review ], [ :payment, :back, :address ] ].freeze

  setup do
    @cart = Cart.create!(status: "open")
    @finds = 0
  end

  def steps = ProgrammingParadigms::PersistedSteps.new(find: -> { @finds += 1; Checkout.for_cart(@cart.id) }, table: TABLE, start: :address,
                                                       jumps: [ [ :payment, :address ] ])
  def stored = Checkout.for_cart(@cart.id).step

  test "an event moves along the table and the record keeps the step" do
    s = steps
    assert_equal :address, s.now
    assert_equal :payment, s.fire(:next)
    assert_equal :review, s.fire(:next)
    assert_equal "review", stored
    assert_equal :review, steps.now
  end

  test "an event the table has no row for stays put" do
    s = steps
    assert_equal :address, s.fire(:back)
    assert_equal :address, s.fire(:unknown)
    assert_equal "address", stored
  end

  test "a URL jump moves only along an allowed edge" do
    s = steps
    assert_equal :address, s.jump(:payment)
    assert_equal "address", stored
    s.fire(:next)
    assert_equal :payment, s.jump(nil)
    assert_equal :payment, s.jump(:review)
    assert_equal :address, s.jump(:address)
    assert_equal "address", stored
  end

  test "restart returns to the start from any step" do
    s = steps
    2.times { s.fire(:next) }
    assert_equal :address, s.restart
    assert_equal "address", stored
  end

  test "reload reads a step moved through another instance" do
    s = steps
    s.fire(:next)
    steps.fire(:next)
    assert_equal :payment, s.now
    s.reload
    assert_equal :review, s.now
  end

  test "the record is found once and kept" do
    s = steps
    s.now
    s.fire(:next)
    s.jump(:address)
    s.restart
    assert_equal 1, @finds
  end
end
