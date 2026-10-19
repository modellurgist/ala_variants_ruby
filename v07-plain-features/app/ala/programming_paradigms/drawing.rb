module ProgrammingParadigms
  # Draws a built composition as a Mermaid flowchart from its `wire` arms, read from its source (R8:
  # the picture is the code), and `running` draws what the trace saw: an edge per hop a test run made.
  # A node per part the composition names; an arm that runs no part lands on the composition. A part
  # that is itself a composition (a feature, with `parts`) is drawn as a subgraph with its own arms
  # inside, and an arm that says `out` leaves it. `gaps` and `unrouted` read the same arms and hops
  # against every part's OUTPUTS, the feature's included.
  module Drawing
    # The drawing's own notation, the same for any app (R3's domain-vocabulary exception)
    INHERENT_LABELS = { request: "request", other_outputs: "every other output" }.freeze

    def self.mermaid(screen) = chart(screen) { |composition, name| arm_edges(composition, name) }

    def self.running(screen) = chart(screen) { |composition, name| hop_edges(composition, name) }

    def self.gaps(screen)
      compositions(screen).reduce({ unwired: [], unknown: [] }) do |acc, (composition, prefix)|
        declared = declared(composition)
        wired = arms(composition.class).flat_map { |a| a[:output] == :_ ? declared.select { _1[0] == a[:part] } : [ [ a[:part], a[:output] ] ] }.uniq
        { unwired: acc[:unwired] + ((declared - wired).map { "#{prefix}#{_1[0]}.#{_1[1]}" } - composition.class::GROUNDED.map { "#{prefix}#{_1}" }),
          unknown: acc[:unknown] + (wired - declared).map { "#{prefix}#{_1[0]}.#{_1[1]}" } }
      end
    end

    def self.unrouted(screen)
      compositions(screen).flat_map do |composition, prefix|
        routed = Foundation::Trace.edges(composition.class).map(&:first)
        declared(composition).reject { routed.include?(_1) }.map { "#{prefix}#{_1[0]}.#{_1[1]}" } - composition.class::GROUNDED.map { "#{prefix}#{_1}" }
      end
    end

    # [{ part:, output:, to: [parts the arm runs], out: [names the arm sends out] }] from `wire`.
    def self.arms(klass)
      source = Prism.parse_file(Object.const_source_location(klass.name).first).value
      wire = find_all(source) { _1.is_a?(Prism::DefNode) && _1.name == :wire }.first or return []
      find_all(wire) { _1.is_a?(Prism::InNode) }.flat_map do |arm|
        patterns(arm.pattern).map do |part, output|
          calls = find_all(arm.statements) { _1.is_a?(Prism::CallNode) && %i[run out].include?(_1.name) && _1.arguments&.arguments&.first.is_a?(Prism::SymbolNode) }
          { part:, output:, to: calls.select { _1.name == :run }.map { _1.arguments.arguments.first.unescaped.to_sym }.uniq,
            out: calls.select { _1.name == :out }.map { _1.arguments.arguments.first.unescaped.to_sym }.uniq }
        end
      end
    end

    def self.declared(composition)
      composition.parts.flat_map { |name, part| part.class.const_defined?(:OUTPUTS) ? part.class::OUTPUTS.map { [ name, _1 ] } : [] }
    end

    # the screen and every feature inside it, each with the prefix its parts are drawn under
    def self.compositions(screen, prefix = "")
      [ [ screen, prefix ] ] + screen.parts.select { |_, part| part.is_a?(Wiring) }.flat_map { |name, part| compositions(part, "#{prefix}#{name}.") }
    end

    def self.chart(screen, &edges)
      lines = [ "flowchart LR", "  screen[[#{screen.class.name}]]" ] + nodes(screen, "") + edges.(screen, "screen")
      (lines.first(2) + lines.drop(2).uniq).join("\n") + "\n"
    end

    def self.nodes(composition, prefix)
      composition.parts.flat_map do |name, part|
        id = "#{prefix}#{name}"
        if part.is_a?(Wiring)
          [ "  subgraph #{id} [#{name}: #{part.class.name.split('::').last}]" ] + nodes(part, "#{id}_") + [ "  end" ]
        else
          [ "  #{id}[#{name}]" ]
        end
      end
    end

    def self.arm_edges(composition, owner, prefix = "")
      own = arms(composition.class).reject { _1[:output] == :_ }.flat_map do |arm|
        from = "#{prefix}#{arm[:part]}"
        targets = arm[:to].map { "#{prefix}#{_1}" } + arm[:out].map { owner }
        (targets.empty? ? [ owner ] : targets).map { "  #{from} -- #{arm[:output]} --> #{_1}" }
      end
      rest = arms(composition.class).select { _1[:output] == :_ }.map { "  #{prefix}#{_1[:part]} -- #{INHERENT_LABELS[:other_outputs]} --> #{owner}" }
      own + rest + features(composition, prefix).flat_map { |id, part| arm_edges(part, id, "#{id}_") }
    end

    def self.hop_edges(composition, owner, prefix = "")
      own = Foundation::Trace.edges(composition.class).map do |from, to|
        target = to == :screen ? owner : "#{prefix}#{to}"
        from == :outside ? "  outside -- #{INHERENT_LABELS[:request]} --> #{target}" : "  #{prefix}#{from[0]} -- #{from[1]} --> #{target}"
      end
      own + features(composition, prefix).flat_map { |id, part| hop_edges(part, id, "#{id}_") }
    end

    def self.features(composition, prefix) = composition.parts.select { |_, part| part.is_a?(Wiring) }.map { |name, part| [ "#{prefix}#{name}", part ] }

    # a pattern is `[:part, :output]`, or several joined by `|`; `_` matches any output
    def self.patterns(node)
      case node
      when Prism::AlternationPatternNode then patterns(node.left) + patterns(node.right)
      when Prism::ArrayPatternNode
        return [] unless node.requireds.size == 2 && node.requireds.first.is_a?(Prism::SymbolNode)
        part = node.requireds.first.unescaped.to_sym
        output = node.requireds.last
        output.is_a?(Prism::SymbolNode) ? [ [ part, output.unescaped.to_sym ] ] : [ [ part, :_ ] ]
      else []
      end
    end

    def self.find_all(node, &pick)
      return [] if node.nil?
      found = pick.(node) ? [ node ] : []
      found + node.compact_child_nodes.flat_map { find_all(_1, &pick) }
    end
  end
end
