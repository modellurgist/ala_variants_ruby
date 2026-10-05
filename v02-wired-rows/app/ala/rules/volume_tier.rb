module Rules
  # The volume-pricing tier for a subtotal, against tiers configured once: [[min_cents, percent, label]], highest first.
  class VolumeTier
    def initialize(tiers:) = @tiers = tiers

    # Returns [percent, label], or [0, nil] below every tier.
    def call(subtotal) = @tiers.find { |min, _, _| subtotal >= min }&.drop(1) || [ 0, nil ]
  end
end
