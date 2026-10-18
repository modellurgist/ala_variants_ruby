module DomainAbstractions
  # Where a shopper is in paying for a cart: a step machine over a flow table, kept in a store of its
  # own, plus the address they enter. Config: store (one record per cart, with `step` and the
  # address columns), cart_id, flow ([[from, event, to]]), start, url_edges (the jumps a URL may
  # make), stock_levels (a lambda of product ids giving { id => stock }), line_items (a
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
      record.update!(step: @start.to_s)
      { step: @start }
    end

    # The URL asks for a step: honour it along an allowed jump, otherwise stay; then show the step.
    def show(requested)
      record.update!(step: requested.to_s) if requested && @url_edges.include?([ step_now, requested ])
      { step: step_now, form: record }
    end

    def validate(params) = { form: record.tap { _1.assign_attributes(params); _1.validate(:address) } }

    def submit_address(params)
      r = record
      r.assign_attributes(params)
      return advance(:submit_address) if r.save(context: :address)
      { step: step_now, form: r }
    end

    def edit_address = advance(:edit_address)

    # Pay for the cart's lines after asking the stock source for fresh levels.
    def pay(cart)
      lines = cart[:lines]
      return { blocked: :empty } if lines.empty?
      return { blocked: :out_of_stock } unless Rules::CheckStock.call(lines, @stock_levels.(lines.map { _1[:product_id] }))
      advance(:pay).merge(ready_to_pay: { line_items: @line_items.call(lines), cart_id: cart[:cart_id] })
    end

    def succeeded(reference)
      record.update!(payment_reference: reference)
      advance(:succeeded).merge(done: reference)
    end

    def failed(_reason) = advance(:failed)

    def initialize(store:, cart_id:, flow:, start:, url_edges:, stock_levels:, line_items:)
      @store, @cart_id, @flow, @start, @url_edges, @stock_levels, @line_items = store, cart_id, flow, start, url_edges, stock_levels, line_items
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
