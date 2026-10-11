module ProgrammingParadigms
  # Event: something happened; no data travels. Senders call send_event.
  module Event
    Port = Data.define(:handler) do
      def send_event(_payload = nil) = handler.()
      alias_method :call, :send_event
    end

    def self.port(&handler) = Port.new(handler)
  end
end
