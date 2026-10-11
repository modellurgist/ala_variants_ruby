# A payment gateway for tests: answers the queued responses in order, recording each charge.
class FakeGateway
  class << self
    attr_accessor :responses, :charges
  end

  def self.reset(responses = [ [ :ok, "chg_test" ] ])
    self.responses = responses.dup
    self.charges = []
  end

  def charge(amount, currency, metadata)
    self.class.charges << { amount:, currency:, metadata: }
    self.class.responses.shift || [ :ok, "chg_test" ]
  end
end
