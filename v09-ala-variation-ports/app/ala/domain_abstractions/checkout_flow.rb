module DomainAbstractions
  # Paying for a cart, on a StepRecord over the page's flow table, kept in a record of its own. Config:
  # steps (that StepRecord), stock_levels (a lambda of product ids giving { id => stock }), line_items
  # (a BuildLineItems). `start` and `pay` take the cart's lines ({ cart_id:, lines: }); `start`
  # answers :empty when there are none, `pay` { blocked: :empty | :out_of_stock } or { payment: }.
  class CheckoutFlow
    def start(cart)
      return :empty if cart[:lines].empty?
      @steps.restart
      nil
    end

    # Pay for the cart's lines after asking the stock source for fresh levels.
    def pay(cart)
      lines = cart[:lines]
      return { blocked: :empty } if lines.empty?
      return { blocked: :out_of_stock } unless Rules::CheckStock.call(lines, @stock_levels.(lines.map { _1[:product_id] }))
      @steps.advance(:pay)
      { payment: { line_items: @line_items.call(lines), cart_id: cart[:cart_id] } }
    end

    def succeeded(reference)
      @steps.record.update!(payment_reference: reference)
      @steps.advance(:succeeded)
    end

    def failed(_reason) = @steps.advance(:failed)

    def initialize(steps:, stock_levels:, line_items:) = (@steps, @stock_levels, @line_items = steps, stock_levels, line_items)
  end
end
