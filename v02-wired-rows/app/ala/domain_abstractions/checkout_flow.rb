module DomainAbstractions
  # Where a shopper is in paying for a cart: a step machine over a flow table, kept in a store of its
  # own, plus the address they enter. Config: store (one record per cart, with `step` and the
  # address columns), cart_id, flow ([[from, event, to]]), start, url_edges (the jumps a URL may
  # make), stock_levels (a lambda of product ids giving { id => stock }), line_items (a
  # BuildLineItems). It pulls the cart's lines through its `lines` port when it starts and when it
  # pays (§4.4.3: a read is pulled). Ports in: start, show, validate, submit_address, edit_address,
  # pay, succeeded, failed. Ports out: step (the step now showing), form (the address
  # record to render, with errors when it has any), blocked (:empty or :out_of_stock), ready_to_pay
  # ({ line_items:, cart_id: }), done (the payment reference, once paid).
  class CheckoutFlow
    include Foundation::Ports
    output :lines, ProgrammingParadigms::RequestResponse
    output :step, ProgrammingParadigms::DataFlow
    output :form, ProgrammingParadigms::DataFlow
    output :blocked, ProgrammingParadigms::DataFlow
    output :ready_to_pay, ProgrammingParadigms::DataFlow, many: true
    output :done, ProgrammingParadigms::DataFlow, many: true

    # Begin: an empty cart can't check out.
    input(:start, ProgrammingParadigms::Event) do
      next emit(:blocked, :empty) if ask(:lines)[:lines].empty?
      record.update!(step: @start.to_s)
      emit(:step, @start)
    end

    # The URL asks for a step: honour it along an allowed jump, otherwise stay; then show the step.
    input(:show, ProgrammingParadigms::DataFlow) do |requested|
      record.update!(step: requested.to_s) if requested && @url_edges.include?([ step_now, requested ])
      emit(:step, step_now)
      emit(:form, record)
    end

    input(:validate, ProgrammingParadigms::DataFlow) { |params| emit(:form, record.tap { _1.assign_attributes(params); _1.validate(:address) }) }

    input(:submit_address, ProgrammingParadigms::DataFlow) do |params|
      r = record
      r.assign_attributes(params)
      next advance(:submit_address) if r.save(context: :address)
      emit(:step, step_now)
      emit(:form, r)
    end

    input(:edit_address, ProgrammingParadigms::Event) { advance(:edit_address) }

    # Pay for the cart's lines after asking the stock source for fresh levels.
    input(:pay, ProgrammingParadigms::Event) do
      cart = ask(:lines)
      lines = cart[:lines]
      next emit(:blocked, :empty) if lines.empty?
      next emit(:blocked, :out_of_stock) unless Rules::CheckStock.call(lines, @stock_levels.(lines.map { _1[:product_id] }))
      advance(:pay)
      emit(:ready_to_pay, line_items: @line_items.call(lines), cart_id: cart[:cart_id])
    end

    input(:succeeded, ProgrammingParadigms::DataFlow) do |reference|
      record.update!(payment_reference: reference)
      advance(:succeeded)
      emit(:done, reference)
    end

    input(:failed, ProgrammingParadigms::DataFlow) { |_reason| advance(:failed) }

    def initialize(store:, cart_id:, flow:, start:, url_edges:, stock_levels:, line_items:)
      @store, @cart_id, @flow, @start, @url_edges, @stock_levels, @line_items = store, cart_id, flow, start, url_edges, stock_levels, line_items
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
