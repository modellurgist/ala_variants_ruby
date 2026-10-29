module DomainAbstractions
  # Submitting a bulk order: a StepRecord over a flow table, kept in a record of its own, plus the
  # purchase order the buyer enters. Config: steps (a StepRecord whose record has the PO columns),
  # cart_id, orders (where the order is placed). The composition
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
      shown = @steps.show(requested)
      shown[:step] == :submitted ? shown.merge(reference: @orders.find_by(cart_id: @cart_id)&.id) : shown
    end

    def edit_lines = @steps.advance(:edit_lines)
    def validate(params) = @steps.validate(params, :submit)

    def submit(params)
      @steps.submit(params, context: :submit, event: :submit_order) { { reference: @orders.place(@cart_id, po_number: _1.po_number).id } }
    end

    def initialize(steps:, cart_id:, orders:) = (@steps, @cart_id, @orders = steps, cart_id, orders)
  end
end
