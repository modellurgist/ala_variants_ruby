module DomainAbstractions
  # Submitting a bulk order, on a StepRecord over the page's flow table whose record holds the
  # purchase order. Config: steps (that StepRecord), cart_id, orders (where the order is placed).
  # `review` takes the order's lines ({ cart_id:, lines: }) and answers :empty when there are none;
  # `submit` answers the placed order, or nil when the PO did not validate; `reference` is the placed
  # order's id.
  class SubmitOrder
    def reference = @orders.find_by(cart_id: @cart_id)&.id

    def review(order)
      return :empty if order[:lines].empty?
      @steps.advance(:go_review)
      nil
    end

    def submit(params)
      @steps.submit(params, context: :submit, event: :submit_order) { { placed: @orders.place(@cart_id, po_number: _1.po_number) } }[:placed]
    end

    def initialize(steps:, cart_id:, orders:) = (@steps, @cart_id, @orders = steps, cart_id, orders)
  end
end
