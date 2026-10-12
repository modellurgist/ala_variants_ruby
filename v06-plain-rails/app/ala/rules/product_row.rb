module Rules
  # Projects a product record into the neutral row a product list displays: id, name, description,
  # amount as Money, thumbnail, stock and its status, and the URLs its actions post to. Config:
  # stock_rule (a StockStatus), links (a lambda of the product id giving { name => url }; the row
  # carries them so no list component knows a route).
  class ProductRow
    def initialize(stock_rule:, links: ->(_id) { {} }) = (@stock_rule, @links = stock_rule, links)

    def call(product)
      { id: product.id, name: product.name, description: product.description, thumbnail: product.thumbnail,
        amount: Foundation::Money[product.amount], stock: product.stock, stock_status: @stock_rule.call(product.stock),
        urls: @links.(product.id) }
    end
  end
end
