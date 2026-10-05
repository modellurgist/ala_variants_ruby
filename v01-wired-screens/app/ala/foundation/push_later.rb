module Foundation
  # The asynchronous execution model (§4.3.2) as an Active Job: a composition enqueues a push to one of
  # its own inputs, and the job rebuilds that composition by name and delivers it. The sender only
  # knows its own port; the composition names itself when it wires the job in.
  class PushLater < ApplicationJob
    def self.port_for(screen, port)
      ProgrammingParadigms::DataFlow.port { |payload| perform_later(screen.class.name, screen.config, port.to_s, payload) }
    end

    def perform(screen_class, config, port, payload)
      screen_class.constantize.new(**config.symbolize_keys).input_port(port.to_sym).push(payload)
    end
  end
end
