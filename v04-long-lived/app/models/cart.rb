class Cart < ApplicationRecord
  STATUSES = %w[open completed abandoned].freeze
  validates :status, inclusion: { in: STATUSES }

  # The id of an open cart for a session: the given one while it is still open, a fresh one otherwise.
  def self.ensure_open(id)
    cart = find_by(id:, status: "open") || create!(status: "open")
    cart.id
  end

  def complete! = update!(status: "completed")

  # The cart's write stamp: every row that belongs to a cart bumps it on commit, so a composition
  # holding the cart in memory can tell when another process wrote.
  def self.bump(id) = where(id:).update_all("version = version + 1")
  def self.version_of(id) = where(id:).pick(:version)
end
