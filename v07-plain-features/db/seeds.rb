# A few products to browse, so the store has something to sell.
[
  [ "Widget", "A dependable widget for everyday widgeting.", 1000, 10, "https://picsum.photos/seed/widget/200" ],
  [ "Gadget", "A gadget with all the gadgetry you expect.", 2500, 5, "https://picsum.photos/seed/gadget/200" ],
  [ "Gizmo", "Limited run; when it's gone it's gone.", 5000, 3, "https://picsum.photos/seed/gizmo/200" ],
  [ "Bulk Widget", "Widgets by the case, for the trade.", 10_000, 50, "https://picsum.photos/seed/bulk/200" ]
].each do |name, description, amount, stock, thumbnail|
  Product.find_or_create_by!(name:) { _1.assign_attributes(description:, amount:, stock:, thumbnail:) }
end
