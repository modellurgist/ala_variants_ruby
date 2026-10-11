namespace :ala do
  desc "Draw every screen's wiring as Mermaid under docs/diagrams/"
  task diagrams: :environment do
    cart = Cart.create!(status: "open")
    FileUtils.mkdir_p("docs/diagrams")
    [ Screens::Catalog, Screens::Cart, Screens::Checkout, Screens::Portal ].each do |screen|
      chart = ProgrammingParadigms::Drawing.mermaid(screen.new(cart_id: cart.id))
      File.write("docs/diagrams/#{screen.name.demodulize.underscore}.md", "# #{screen.name}\n\n```mermaid\n#{chart}```\n")
      puts "docs/diagrams/#{screen.name.demodulize.underscore}.md"
    end
  ensure
    cart&.destroy
  end
end
