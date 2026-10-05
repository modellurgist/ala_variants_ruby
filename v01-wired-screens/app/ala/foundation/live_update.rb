module Foundation
  # A sink that sends a rendered component to every open page on a Turbo stream (§4.7: the composition
  # wires the publisher; pages subscribe with turbo_stream_from). Config: stream, action (:append,
  # :replace, :remove, or :replace_all for a CSS selector), target (a string or a lambda of the
  # payload), render (a lambda of the payload giving HTML; omitted for :remove).
  class LiveUpdate
    include Ports

    input(:push, ProgrammingParadigms::DataFlow) do |payload|
      target = @target.respond_to?(:call) ? @target.(payload) : @target
      html = @render&.call(payload)
      case @action
      when :replace_all then Turbo::StreamsChannel.broadcast_replace_to(@stream, targets: target, html:)
      when :remove then Turbo::StreamsChannel.broadcast_remove_to(@stream, target:)
      else Turbo::StreamsChannel.broadcast_action_to(@stream, action: @action, target:, html:)
      end
    end

    def initialize(stream:, action:, target:, render: nil) = (@stream, @action, @target, @render = stream, action, target, render)

    # Renders a component partial outside a request, for a broadcast.
    def self.component(name, **locals) = ApplicationController.render(partial: "components/#{name}", locals:)
  end
end
