class Cart < ApplicationRecord
  STATUSES = %w[open completed abandoned].freeze
  validates :status, inclusion: { in: STATUSES }

  # The id of an open cart for a session: the given one while it is still open, a fresh one otherwise.
  def self.ensure_open(id)
    cart = find_by(id:, status: "open") || create!(status: "open")
    cart.id
  end

  def complete! = update!(status: "completed")
end
