module Rules
  # Validates a promo code against a code table configured once: { "CODE" => percent }.
  class ValidatePromo
    def initialize(codes:) = @codes = codes

    # Returns [normalized_code, percent] or nil.
    def call(code)
      normal = code.to_s.strip.upcase
      percent = @codes[normal] and [ normal, percent ]
    end
  end
end
