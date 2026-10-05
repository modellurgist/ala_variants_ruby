module Rules
  # Shipping by method, against a rate table configured once: { method => { label:, cost:, free_above: } }.
  class CalculateShipping
    def initialize(rates:) = @rates = rates

    def call(method, subtotal)
      rate = @rates[method]
      return 0 if subtotal.zero? || rate.nil?
      rate[:free_above] && subtotal >= rate[:free_above] ? 0 : rate[:cost]
    end

    def label(method) = @rates.dig(method, :label)
    def options = @rates.map { |method, rate| rate.merge(method:) }
    def method?(method) = @rates.key?(method)
  end
end
