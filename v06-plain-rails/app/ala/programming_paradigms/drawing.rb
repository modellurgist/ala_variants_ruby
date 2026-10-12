module ProgrammingParadigms
  # Draws a composition as a Mermaid flowchart from its `wire` arms, read from its source (R8: the
  # picture is the code), and `running` draws what the trace saw: an edge per hop a test run made.
  # A node per part the composition names; an arm that runs no part lands on the composition.
  module Drawing
    def self.mermaid(screen_class)
      edges = arms(screen_class).flat_map do |arm|
        to = arm[:to].empty? ? [ "screen" ] : arm[:to]
        to.map { "  #{arm[:part]} -- #{arm[:output]} --> #{_1}" }
      end
      chart(screen_class, edges)
    end

    def self.running(screen_class)
      edges = Foundation::Trace.edges(screen_class).map do |from, to|
        from == :outside ? "  outside -- request --> #{to}" : "  #{from[0]} -- #{from[1]} --> #{to}"
      end
      chart(screen_class, edges)
    end

    def self.chart(screen_class, edges)
      parts = arms(screen_class).flat_map { [ _1[:part] ] + _1[:to] }.uniq
      ([ "flowchart LR", "  screen[[#{screen_class.name}]]" ] + parts.map { "  #{_1}[#{_1}]" } + edges.uniq).join("\n") + "\n"
    end

    # [{ part:, output:, to: [parts the arm runs] }] from the `case [part, output]` in `wire`.
    def self.arms(screen_class)
      source = Prism.parse_file(Object.const_source_location(screen_class.name).first).value
      wire = find_all(source) { _1.is_a?(Prism::DefNode) && _1.name == :wire }.first or return []
      find_all(wire) { _1.is_a?(Prism::InNode) }.filter_map do |arm|
        pattern = arm.pattern
        next unless pattern.is_a?(Prism::ArrayPatternNode) && pattern.requireds.size == 2 && pattern.requireds.all?(Prism::SymbolNode)
        part, output = pattern.requireds.map { _1.unescaped.to_sym }
        to = find_all(arm.statements) { _1.is_a?(Prism::CallNode) && _1.name == :run && _1.arguments&.arguments&.first.is_a?(Prism::SymbolNode) }
        { part:, output:, to: to.map { _1.arguments.arguments.first.unescaped.to_sym }.uniq }
      end
    end

    def self.find_all(node, &pick)
      return [] if node.nil?
      found = pick.(node) ? [ node ] : []
      found + node.compact_child_nodes.flat_map { find_all(_1, &pick) }
    end
  end
end

module ProgrammingParadigms
  module Drawing
    # The [part, output] pairs the arms wire, against what the parts declare in OUTPUTS and what the
    # composition grounds on purpose: a coverage test is one assertion.
    def self.gaps(screen)
      declared = declared(screen)
      wired = arms(screen.class).map { [ _1[:part], _1[:output] ] }.uniq
      { unwired: (declared - wired).map { "#{_1[0]}.#{_1[1]}" } - screen.class::GROUNDED.map(&:to_s), unknown: (wired - declared).map { "#{_1[0]}.#{_1[1]}" } }
    end

    # Declared outputs no hop ever left from while the trace was on, less those grounded.
    def self.unrouted(screen)
      routed = Foundation::Trace.edges(screen.class).map(&:first)
      declared(screen).reject { routed.include?(_1) }.map { "#{_1[0]}.#{_1[1]}" } - screen.class::GROUNDED.map(&:to_s)
    end

    def self.declared(screen)
      screen.parts.flat_map { |name, part| part.class.const_defined?(:OUTPUTS) ? part.class::OUTPUTS.map { [ name, _1 ] } : [] }
    end
  end
end
