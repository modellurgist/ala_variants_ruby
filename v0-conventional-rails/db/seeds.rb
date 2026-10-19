[
  { name: "Espresso Beans", description: "Dark roast, 1 kg bag", amount: 2499, stock: 40, thumbnail: "https://picsum.photos/seed/beans/96" },
  { name: "Pour-over Kettle", description: "Gooseneck, 1 L", amount: 5900, stock: 12, thumbnail: "https://picsum.photos/seed/kettle/96" },
  { name: "Ceramic Mug", description: "350 ml, stoneware", amount: 1500, stock: 4, thumbnail: "https://picsum.photos/seed/mug/96" },
  { name: "Burr Grinder", description: "Conical burrs, 40 settings", amount: 12900, stock: 7, thumbnail: "https://picsum.photos/seed/grinder/96" },
  { name: "Paper Filters", description: "Pack of 100", amount: 699, stock: 0, thumbnail: "https://picsum.photos/seed/filters/96" }
].each do |attributes|
  Product.find_or_create_by!(name: attributes[:name]) { |product| product.assign_attributes(attributes) }
end
