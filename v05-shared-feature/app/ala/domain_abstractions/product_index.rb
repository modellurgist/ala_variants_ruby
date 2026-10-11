module DomainAbstractions
  # Answers product rows by id, for the features that hold product ids and need what a product
  # looks like (R10: they share the identity key, not the record). Config: model (the products
  # store), project (a record to a row). Port in: lookup, a request of product ids answered with
  # { id => row }.
  class ProductIndex
    include Foundation::Ports

    input(:lookup, ProgrammingParadigms::RequestResponse) { |ids| @model.where(id: ids).to_h { [ _1.id, @project.(_1) ] } }

    def initialize(model:, project:) = (@model, @project = model, project)
  end
end
