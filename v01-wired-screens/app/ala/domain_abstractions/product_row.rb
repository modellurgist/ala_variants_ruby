module DomainAbstractions
  # Projects a product record into the neutral row a product list displays: id, name, description,
  # amount as Money, thumbnail, stock and its status. Config: stock_rule (a StockStatus).
  class ProductRow
    def initialize(stock_rule:) = @stock_rule = stock_rule

    def call(product)
      { id: product.id, name: product.name, description: product.description, thumbnail: product.thumbnail,
        amount: Foundation::Money[product.amount], stock: product.stock, stock_status: @stock_rule.call(product.stock) }
    end
  end
end
