module Rules
  # Gift-wrap cost for a number of wrapped items, at a unit cost configured once.
  class CalculateGiftWrapCost
    def initialize(unit:) = @unit = unit
    def call(count) = count * @unit
  end
end
