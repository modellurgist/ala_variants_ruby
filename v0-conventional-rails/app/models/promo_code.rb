module PromoCode
  def self.percent_for(code)
    Rails.configuration.x.store.promo_codes[code.to_s.to_sym]
  end
end
