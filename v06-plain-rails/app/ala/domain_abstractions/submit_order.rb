module DomainAbstractions
  # Submitting a bulk order: its steps, and the purchase order the buyer enters. Config: steps (a
  # Wizard over the draft's submission record, with `step` and the PO columns), cart_id, orders
  # (where the order is placed). The composition
  # hands it the order's lines when the buyer asks to review. In: review ({ cart_id:, lines: }), show
  # (the step a URL asks for), edit_lines, validate, submit. Out: step, form (the PO record to render,
  # after show, validate or a failed submit), blocked (:empty), reference (the placed order's id).
  class SubmitOrder
    OUTPUTS = %i[step form blocked reference].freeze

    def review(order)
      return { blocked: :empty } if order[:lines].empty?
      @steps.advance(:go_review)
    end

    def show(requested)
      shown = @steps.visit(requested)
      shown[:step] == :submitted ? shown.merge(reference: @orders.find_by(cart_id: @cart_id)&.id) : shown
    end

    def edit_lines = @steps.advance(:edit_lines)
    def validate(params) = @steps.validate(params, :submit)

    def submit(params)
      return @steps.shown unless @steps.save(params, :submit)
      order = @orders.place(@cart_id, po_number: @steps.record.po_number)
      @steps.advance(:submit_order).merge(reference: order.id)
    end

    def initialize(steps:, cart_id:, orders:) = (@steps, @cart_id, @orders = steps, cart_id, orders)
  end
end
