module DomainAbstractions
  # Submitting a bulk order: a step machine over a flow table, kept in a store of its own, plus the
  # purchase order the buyer enters. Config: store (one record per cart, with `step` and the PO
  # columns), cart_id, flow, start, url_edges, orders (where the order is placed). It pulls the
  # order's lines through its `lines` port when the buyer asks to review. Ports in: review, show (the
  # step a URL asks for), edit_lines, validate, submit. Ports out: step, form (the PO record to render,
  # after show, validate or a failed submit), blocked (:empty), reference (the placed order's id).
  class SubmitOrder
    include Foundation::Ports
    output :lines, ProgrammingParadigms::RequestResponse
    output :step, ProgrammingParadigms::DataFlow
    output :form, ProgrammingParadigms::DataFlow
    output :blocked, ProgrammingParadigms::DataFlow
    output :reference, ProgrammingParadigms::DataFlow, many: true

    input(:review, ProgrammingParadigms::Event) do
      next emit(:blocked, :empty) if ask(:lines)[:lines].empty?
      advance(:go_review)
    end

    input(:show, ProgrammingParadigms::DataFlow) do |requested|
      record.update!(step: requested.to_s) if requested && @url_edges.include?([ step_now, requested ])
      emit(:step, step_now)
      emit(:form, record)
      emit(:reference, @orders.find_by(cart_id: @cart_id)&.id) if step_now == :submitted
    end

    input(:edit_lines, ProgrammingParadigms::Event) { advance(:edit_lines) }
    input(:validate, ProgrammingParadigms::DataFlow) { |params| emit(:form, record.tap { _1.assign_attributes(params); _1.validate(:submit) }) }

    input(:submit, ProgrammingParadigms::DataFlow) do |params|
      r = record
      r.assign_attributes(params)
      next (emit(:step, step_now); emit(:form, r)) unless r.save(context: :submit)
      order = @orders.place(@cart_id, po_number: r.po_number)
      advance(:submit_order)
      emit(:reference, order.id)
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
      emit(:step, to)
    end
  end
end
