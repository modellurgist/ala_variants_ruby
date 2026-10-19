class FakePaymentGateway
  cattr_accessor :declines, :sessions

  def self.reset
    self.declines = false
    self.sessions = []
  end

  def checkout(line_items:, success_url:)
    sessions << line_items
    success_url unless declines
  end
end
