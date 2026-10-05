module ProgrammingParadigms
  # The UI-layout paradigm (§1.6.6): a line on the diagram meaning "display inside". A container's
  # `contains` port accepts UI elements; each answers `render` with its lines of text.
  module UiLayout
    Port = Data.define(:handler) do
      def render = handler.()
      alias_method :call, :render
    end

    def self.port(&handler) = Port.new(handler)
  end
end
