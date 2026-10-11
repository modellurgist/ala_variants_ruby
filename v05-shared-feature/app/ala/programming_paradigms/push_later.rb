module ProgrammingParadigms
  # The asynchronous execution model (§4.3.2) as an Active Job: a composition enqueues a push to one of
  # its own inputs, and the job delivers it into the kept composition for the same key (see
  # `LongLived`), building one in the job's process if it has none. The sender only knows its own
  # port; the composition names the registry it lives in when it wires the job in.
  class PushLater < ApplicationJob
    def self.port_for(registry, key, port)
      ProgrammingParadigms::DataFlow.port { |payload| perform_later(registry.to_s, key, port.to_s, payload) }
    end

    def perform(registry, key, port, payload)
      LongLived.named(registry.to_sym).with(key) { _1.input_port(port.to_sym).push(payload) }
    end
  end
end
