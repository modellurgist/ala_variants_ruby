module Foundation
  # An analogue-to-digital converter the application reads one sample at a time. Config: samples
  # (anything enumerable, the hardware in a test). Answers the next raw reading, or nil when done.
  class Adc
    def initialize(samples:) = @samples = samples.each

    def read
      @samples.next
    rescue StopIteration
      nil
    end
  end
end
