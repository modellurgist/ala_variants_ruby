namespace :ala do
  desc "Draw every screen's wiring as Mermaid under docs/diagrams/, from its wire arms"
  task diagrams: :environment do
    FileUtils.mkdir_p("docs/diagrams")
    cart = Cart.create!(status: "open")
    [ Screens::Catalog, Screens::Cart, Screens::Checkout, Screens::Portal ].each do |screen|
      chart = ProgrammingParadigms::Drawing.mermaid(screen.new(cart_id: cart.id))
      File.write("docs/diagrams/#{screen.name.demodulize.underscore}.md", "# #{screen.name}\n\n```mermaid\n#{chart}```\n")
      puts "docs/diagrams/#{screen.name.demodulize.underscore}.md"
    end
  ensure
    cart&.destroy
  end
end
