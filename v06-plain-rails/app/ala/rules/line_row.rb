module Rules
  # A held line as a list shows it: the row of the product it names, overlaid with the line's own fields
  # (its id among them) and the URLs its actions post to. Each product is looked up once; `fill` looks
  # up a batch ahead of a loop. Config: products (a lambda of product ids giving { id => row }), links
  # (a lambda of the line's id). V05's `LineRow` (no cache, chosen fields) and V07's `HeldProducts` are the
  # same projection, extracted separately (2026-10-19).
  class LineRow
    def initialize(products:, links: ->(_id) { {} }) = (@lookup, @links, @products = products, links, {})

    def fill(product_ids)
      missing = product_ids.uniq - @products.keys
      @products.merge!(@lookup.(missing)) unless missing.empty?
    end

    def product(id) = (fill([ id ]); @products.fetch(id))
    def call(line) = product(line[:product_id]).merge(line, urls: @links.(line[:id]))
  end
end
