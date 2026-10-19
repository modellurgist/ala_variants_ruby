module Rules
  # A held line shown as the product it refers to: the product row's display fields under the line's
  # own id and URLs, with the line's own fields beside them. Config: fields (the product row's keys a
  # row carries), links (a lambda of the line's id giving { name => url }). V06's `LineRow` and V07's
  # `HeldProducts` cover the same projection with a product cache; extracted separately (2026-10-19).
  class LineRow
    def initialize(fields:, links: ->(_id) { {} }) = (@fields, @links = fields, links)

    def call(id, product, **line) = { id:, **product.slice(*@fields), **line, urls: @links.(id) }
  end
end
