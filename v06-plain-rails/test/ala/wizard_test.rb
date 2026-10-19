require "test_helper"

# Exercised on a checkout record for its `step` column and its :address validations; the flow is the test's own.
class WizardTest < ActiveSupport::TestCase
  FLOW = [ [ :address, :next, :payment ], [ :payment, :next, :review ], [ :payment, :back, :address ] ].freeze
  ADDRESS = { name: "Ada", line1: "1 Ave", city: "L", postal_code: "12345" }.freeze

  setup do
    @cart = Cart.create!(status: "open")
    @finds = 0
  end

  def wizard = ProgrammingParadigms::Wizard.new(record: -> { @finds += 1; Checkout.for_cart(@cart.id) }, flow: FLOW, start: :address,
                                                url_edges: [ [ :payment, :address ] ])
  def stored = Checkout.for_cart(@cart.id)

  test "an event advances along the flow and the record keeps the step" do
    w = wizard
    assert_equal :address, w.step
    assert_equal({ step: :payment }, w.advance(:next))
    assert_equal({ step: :review }, w.advance(:next))
    assert_equal "review", stored.step
    assert_equal :review, wizard.step
  end

  test "an event the flow has no row for stays put" do
    w = wizard
    assert_equal({ step: :address }, w.advance(:back))
    assert_equal({ step: :address }, w.advance(:unknown))
    assert_equal "address", stored.step
  end

  test "a visited URL moves only along a url edge, and answers the step with the form" do
    w = wizard
    assert_equal({ step: :address, form: w.record }, w.visit(:payment))
    w.advance(:next)
    assert_equal :payment, w.visit(nil)[:step]
    assert_equal :payment, w.visit(:review)[:step]
    assert_equal :address, w.visit(:address)[:step]
    assert_equal "address", stored.step
  end

  test "restart returns to the start from any step" do
    w = wizard
    2.times { w.advance(:next) }
    assert_equal({ step: :address }, w.restart)
    assert_equal "address", stored.step
  end

  test "validate fills the form and checks it in the context given, saving nothing" do
    form = wizard.validate({ name: "Ada" }, :address)[:form]
    assert_equal "Ada", form.name
    assert form.errors.of_kind?(:city, :blank)
    assert_nil stored.name
    assert_empty wizard.validate({ name: "Ada" }, nil)[:form].errors
  end

  test "save stores the form only when it is valid in the context given" do
    assert_not wizard.save({ name: "Ada" }, :address)
    assert_nil stored.name
    assert wizard.save(ADDRESS, :address)
    assert_equal "12345", stored.postal_code
  end

  test "the record is found once and kept" do
    w = wizard
    w.step
    w.advance(:next)
    w.visit(:address)
    w.restart
    w.validate({}, nil)
    assert_equal 1, @finds
  end
end
