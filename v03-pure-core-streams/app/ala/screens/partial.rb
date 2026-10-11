module Screens
  # Renders a partial outside a request, for a screen's live updates.
  module Partial
    def self.render(path, **locals) = ApplicationController.render(partial: path, locals:)
  end
end
