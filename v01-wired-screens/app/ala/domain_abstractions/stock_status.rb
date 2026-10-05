module DomainAbstractions
  # Classifies a stock level as in stock, low, or out, against a low-stock threshold the composition
  # configures once. Config: low_at.
  class StockStatus
    def initialize(low_at:) = @low_at = low_at

    def call(stock)
      return :out_of_stock if stock <= 0
      stock <= @low_at ? :low_stock : :in_stock
    end
  end
end
