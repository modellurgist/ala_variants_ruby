module DomainAbstractions
  # Submitting a bulk order: a step machine over a flow table, kept in a store of its own, plus the
  # purchase order the buyer enters. Config: store (one record per cart, with `step` and the PO
  # columns), cart_id, flow, start, url_edges, orders (where the order is placed). The composition
  # hands it the order's lines when the buyer asks to review. In: review ({ cart_id:, lines: }), show
  # (the step a URL asks for), edit_lines, validate, submit. Out: step, form (the PO record to render,
  # after show, validate or a failed submit), blocked (:empty), reference (the placed order's id).
  class SubmitOrder
    OUTPUTS = %i[step form blocked reference].freeze

    def review(order)
      return { blocked: :empty } if order[:lines].empty?
      advance(:go_review)
    end

    def show(requested)
      record.update!(step: requested.to_s) if requested && @url_edges.include?([ step_now, requested ])
      shown = { step: step_now, form: record }
      step_now == :submitted ? shown.merge(reference: @orders.find_by(cart_id: @cart_id)&.id) : shown
    end

    def edit_lines = advance(:edit_lines)
    def validate(params) = { form: record.tap { _1.assign_attributes(params); _1.validate(:submit) } }

    def submit(params)
      r = record
      r.assign_attributes(params)
      return { step: step_now, form: r } unless r.save(context: :submit)
      order = @orders.place(@cart_id, po_number: r.po_number)
      advance(:submit_order).merge(reference: order.id)
    end

    def initialize(store:, cart_id:, flow:, start:, url_edges:, orders:)
      @store, @cart_id, @flow, @start, @url_edges, @orders = store, cart_id, flow, start, url_edges, orders
    end

    private

    def record = @record ||= @store.for_cart(@cart_id)
    def step_now = record.step.to_sym

    def advance(event)
      moved, to = ProgrammingParadigms::Transitions.step(@flow, step_now, event)
      record.update!(step: to.to_s) if moved == :moved
      { step: to }
    end
  end
end
