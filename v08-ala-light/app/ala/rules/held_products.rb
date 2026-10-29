module Rules
  # Entries a shopper holds that each name a product (a cart line, a saved item, a wished product's
  # id), in order, with what their products look like: asked of the products lambda once per load and
  # again only for a product new since. A row is what every list of them shows. Config: products (a
  # lambda of product ids giving { id => row }), links (an entry's id to its row's URLs; none by default), id and
  # product_id (an entry to its own id and its product's; by default its :id and :product_id). V05's and
  # V06's `LineRow` cover the row half of this, extracted separately (2026-10-19).
  class HeldProducts
    def load(entries) = (@entries, @catalog = entries, @products.(entries.map(&@product_id).uniq))

    # An entry with an id already held replaces it.
    def add(entry)
      @entries.reject! { @id.(_1) == @id.(entry) }
      @entries << entry
      @catalog.merge!(@products.([ @product_id.(entry) ])) unless @catalog.key?(@product_id.(entry))
    end

    def find(id) = (@entries.find { @id.(_1) == id } or raise ArgumentError, "nothing held as #{id}")
    def take(id) = find(id).tap { @entries.delete(_1) }
    def entries = @entries.dup
    def product(entry) = @catalog.fetch(@product_id.(entry))

    def row(entry)
      p = product(entry)
      { id: @id.(entry), name: p[:name], thumbnail: p[:thumbnail], amount: p[:amount], urls: @links.(@id.(entry)) }
    end

    def rows = @entries.map { row(_1) }

    def initialize(products:, links: ->(_id) { {} }, id: ->(e) { e[:id] }, product_id: ->(e) { e[:product_id] })
      @products, @links, @id, @product_id, @entries, @catalog = products, links, id, product_id, [], {}
    end
  end
end
