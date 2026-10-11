module ProgrammingParadigms
  # Push dataflow: a stream of values without end. Senders call push; receivers get each value.
  module DataFlow
    Port = Data.define(:handler) do
      def push(value) = handler.(value)
      alias_method :call, :push
    end

    def self.port(&handler) = Port.new(handler)
  end
end
