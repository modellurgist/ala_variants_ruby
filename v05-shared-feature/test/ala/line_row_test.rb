require "test_helper"

class LineRowTest < ActiveSupport::TestCase
  PRODUCT = { id: 7, name: "Widget", amount: Foundation::Money[1000], stock: 3, thumbnail: "w.png", description: "d" }.freeze

  test "a row is the line's id, the chosen product fields, the line's fields and the line's URLs" do
    row = Rules::LineRow.new(fields: %i[name amount], links: ->(id) { { remove: "/lines/#{id}" } })
    assert_equal({ id: 42, name: "Widget", amount: Foundation::Money[1000], quantity: 2, gift_wrapped: true, urls: { remove: "/lines/42" } },
                 row.call(42, PRODUCT, quantity: 2, gift_wrapped: true))
  end

  test "a row carries no product field it was not configured with, and no URLs without links" do
    assert_equal({ id: 42, thumbnail: "w.png", urls: {} }, Rules::LineRow.new(fields: %i[thumbnail]).call(42, PRODUCT))
    assert_equal({ id: 42, urls: {} }, Rules::LineRow.new(fields: []).call(42, PRODUCT))
  end
end
