module Screens
  # Renders a partial outside a request, for a screen's patches. `each` lets the framework iterate,
  # so a row that has gone renders as nothing.
  module Partial
    def self.render(path, **locals) = ApplicationController.render(partial: path, locals:)
    def self.each(path, rows, **locals) = ApplicationController.render(partial: path, collection: rows, as: :row, locals:)
  end
end
