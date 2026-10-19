ShippingMethod = Data.define(:key, :label, :cents, :free_above_cents) do
  def self.all
    Rails.configuration.x.store.shipping_methods.map do |key, options|
      new(key: key.to_s, label: options[:label], cents: options[:cents], free_above_cents: options[:free_above_cents])
    end
  end

  def self.keys
    all.map(&:key)
  end

  def self.find(key)
    all.find { |method| method.key == key.to_s }
  end

  def cost_for(subtotal)
    return 0 if subtotal.zero? || (free_above_cents && subtotal >= free_above_cents)

    cents
  end
end
