module Foundation
  # The default payment gateway: an in-process ledger that settles a charge at once and hands back an
  # opaque reference. A real processor drops in behind the same call: charge(amount_cents, currency,
  # metadata) answering [:ok, reference] or [:error, reason].
  class LedgerGateway
    def charge(amount_cents, currency, _metadata)
      return [ :error, :invalid_charge ] unless amount_cents.is_a?(Integer) && amount_cents.positive? && currency.is_a?(String)
      [ :ok, "chg_#{SecureRandom.hex}" ]
    end
  end
end
