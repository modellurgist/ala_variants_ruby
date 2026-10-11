module ProgrammingParadigms
  # Request/response: the requester gets an answer back from whatever it is wired to (§4.6). Used
  # for reads of a store and for pulls the requester needs before it can go on.
  module RequestResponse
    Port = Data.define(:handler) do
      def request(query = nil) = handler.(query)
      alias_method :call, :request
    end

    def self.port(&handler) = Port.new(handler)
  end
end
