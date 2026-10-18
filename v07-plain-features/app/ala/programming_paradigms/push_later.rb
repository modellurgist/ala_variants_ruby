module ProgrammingParadigms
  # The asynchronous execution model (§4.3.2) as an Active Job: a composition enqueues a push to one of
  # its own inputs, and the job rebuilds that composition by name and calls it. The sender only knows
  # its own input; the composition names itself when it enqueues.
  class PushLater < ApplicationJob
    def self.push(screen, input, payload) = perform_later(screen.class.name, screen.config, input.to_s, payload)

    def perform(screen_class, config, input, payload) = screen_class.constantize.new(**config.symbolize_keys).public_send(input, payload)
  end
end
