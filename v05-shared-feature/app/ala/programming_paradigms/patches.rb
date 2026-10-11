module ProgrammingParadigms
  # A response built from patches: what one request's outputs changed on the page, as Turbo Stream
  # actions the controller renders instead of redirecting. A `Patch` sink adds to it; `render` turns
  # it into the tags a `turbo_stream` builder makes. Knows Turbo; never a screen or a feature.
  class Patches
    def initialize = @actions = []

    # The last patch of a target wins: a summary patched by every load and change is sent once.
    def add(action, target, html)
      @actions.reject! { |a, t, _| a == action && t == target && action != :append }
      @actions << [ action, target, html ]
    end
    def any? = @actions.any?
    def clear = @actions.clear
    def size = @actions.size

    def render(builder) = @actions.map { |action, target, html| html.nil? ? builder.public_send(action, target) : builder.public_send(action, target, html) }
  end

  # A sink that turns one output into one patch. Config: patches (the buffer), action (:replace,
  # :update, :append, :prepend or :remove), target (a DOM id, or a lambda of the payload), render (a
  # lambda of the payload giving HTML; omitted for :remove). In: push (the payload).
  class Patch
    include Foundation::Ports

    input(:push, ProgrammingParadigms::DataFlow) do |payload|
      target = @target.respond_to?(:call) ? @target.(payload) : @target
      @patches.add(@action, target, @render&.call(payload))
    end

    def initialize(patches:, action:, target:, render: nil) = (@patches, @action, @target, @render = patches, action, target, render)
  end
end
