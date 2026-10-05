module Foundation
  # An amount in cents, shown as dollars. The one money type every layer may depend on.
  Money = Data.define(:cents) do
    def self.[](cents) = new(cents: Integer(cents))

    def to_s = format("%s$%d.%02d", cents.negative? ? "-" : "", cents.abs / 100, cents.abs % 100)
    def zero? = cents.zero?
    def positive? = cents.positive?
    def +(other) = Money[cents + other.cents]
    def *(n) = Money[cents * n]
  end
end
