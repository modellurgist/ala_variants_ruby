module Rules
  # Turns stored lines into payment line items, in the currency the store configures once.
  class BuildLineItems
    def initialize(currency:) = @currency = currency

    def call(lines)
      lines.map do |line|
        { name: line[:name], description: line[:description], image_url: line[:thumbnail],
          unit_amount: line[:amount], currency: @currency, quantity: line[:quantity] }
      end
    end
  end
end
