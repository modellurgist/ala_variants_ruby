module ProgrammingParadigms
  # A response built from patches: what one request changed on the page, as Turbo Stream actions the
  # controller renders instead of redirecting. The composition's arms add to it; `render` turns it
  # into the tags a `turbo_stream` builder makes. Knows Turbo; never a screen or a feature.
  class Patches
    def initialize = @actions = []

    def append(target, html) = add(:append, target, html)
    def replace(target, html) = add(:replace, target, html)
    def replace_all(selector, html) = add(:replace_all, selector, html)
    def update(target, html) = add(:update, target, html)
    def remove(target) = add(:remove, target, nil)
    def any? = @actions.any?
    def size = @actions.size

    def render(builder) = @actions.map { |action, target, html| html.nil? ? builder.public_send(action, target) : builder.public_send(action, target, html) }

    private

    # The last patch of a target wins: a summary patched by every load and change is sent once.
    def add(action, target, html)
      @actions.reject! { |a, t, _| a == action && t == target && action != :append }
      @actions << [ action, target, html ]
      nil
    end
  end
end
