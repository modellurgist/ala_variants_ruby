module DomainAbstractions
  # Where a shopper is in paying for a cart: a StepRecord over a flow table, kept in a record of its
  # own, plus the address they enter. Config: steps (a StepRecord whose record has the address
  # columns), stock_levels (a lambda of product ids giving { id => stock }), line_items (a
  # BuildLineItems). The composition hands it the cart's lines when it starts and when it pays
  # (§4.4.3: a read is pulled). In: start and pay ({ cart_id:, lines: }), show, validate,
  # submit_address, edit_address, succeeded, failed. Out: step (the step now showing), form (the
  # address record to render, with errors when it has any), blocked (:empty or :out_of_stock),
  # ready_to_pay ({ line_items:, cart_id: }), done (the payment reference, once paid).
  class CheckoutFlow
    OUTPUTS = %i[step form blocked ready_to_pay done].freeze

    # Begin: an empty cart can't check out.
    def start(cart)
      return { blocked: :empty } if cart[:lines].empty?
      @steps.restart
    end

    # ala:accept passthrough -- delegation to StepRecord in place of inheriting it (§7.16)
    def show(requested) = @steps.show(requested)
    def validate(params) = @steps.validate(params, :address)
    def submit_address(params) = @steps.submit(params, context: :address, event: :submit_address)
    def edit_address = @steps.advance(:edit_address)

    # Pay for the cart's lines after asking the stock source for fresh levels.
    def pay(cart)
      lines = cart[:lines]
      return { blocked: :empty } if lines.empty?
      return { blocked: :out_of_stock } unless Rules::CheckStock.call(lines, @stock_levels.(lines.map { _1[:product_id] }))
      @steps.advance(:pay).merge(ready_to_pay: { line_items: @line_items.call(lines), cart_id: cart[:cart_id] })
    end

    def succeeded(reference)
      @steps.record.update!(payment_reference: reference)
      @steps.advance(:succeeded).merge(done: reference)
    end

    def failed(_reason) = @steps.advance(:failed)

    def initialize(steps:, stock_levels:, line_items:) = (@steps, @stock_levels, @line_items = steps, stock_levels, line_items)
  end
end
