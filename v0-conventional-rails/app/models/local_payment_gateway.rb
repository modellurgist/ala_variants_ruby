# The default provider settles in-process. A hosted provider would return its own checkout page URL,
# or nil when the session can't be opened.
class LocalPaymentGateway
  def checkout(line_items:, success_url:)
    success_url if line_items.any?
  end
end
