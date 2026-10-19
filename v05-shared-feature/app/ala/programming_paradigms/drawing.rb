module ProgrammingParadigms
  # Draws a built composition as a Mermaid flowchart by walking its object graph (R8: the picture
  # can't drift from the code). A node per part the composition names, an edge per wire labelled
  # `output → input`; an output wired to a block lands on the composition itself, and an instance or
  # port the composition made inline (a sink, a job's port) is drawn by what it is. A part that is
  # itself a composition (a feature, whose `parts` are not empty) is drawn as a subgraph with its own
  # wires inside. `running` draws the same graph with the wires `Foundation::Trace` saw carry
  # something as solid lines and the rest dotted; `unfired` lists the rest.
  module Drawing
    def self.mermaid(screen) = chart(screen) { |_part, _wire| true }

    def self.running(screen) = chart(screen) { |part, wire| Foundation::Trace.fired?(part, wire) }

    def self.unfired(screen, prefix = "")
      screen.parts.flat_map do |name, part|
        own = part.wires.reject { Foundation::Trace.fired?(part, _1) }.map { "#{prefix}#{name}.#{_1.output}#{_1.input && " → #{_1.input}"}" }
        own + unfired(part, "#{prefix}#{name}.")
      end
    end

    def self.chart(screen, &fired)
      ([ "flowchart LR", "  screen[[#{screen.class.name}]]" ] + nodes(screen, "") + numbered(edges(screen, "", "screen", &fired).uniq)).join("\n") + "\n"
    end

    # object ids change from run to run; numbering inline instances by first appearance keeps a drawing stable
    def self.numbered(lines)
      ids = {}
      lines.map { |line| line.gsub(/_(\d+)\(\[/) { "_#{ids[$1] ||= ids.size + 1}([" } }
    end

    def self.nodes(composition, prefix)
      composition.parts.flat_map do |name, part|
        id = "#{prefix}#{name}"
        if part.parts.any?
          [ "  subgraph #{id} [#{name}: #{part.class.name.split('::').last}]" ] + nodes(part, "#{id}_") + [ "  end" ]
        else
          [ "  #{id}[#{name}: #{part.class.name.split('::').last}]" ]
        end
      end
    end

    # a wire to a block lands on the composition that made it: the screen, or the feature's subgraph
    def self.edges(composition, prefix, owner, &fired)
      names = composition.parts.to_h { |name, part| [ part, "#{prefix}#{name}" ] }
      composition.parts.flat_map do |name, part|
        own = part.wires.map { edge("#{prefix}#{name}", _1, names, owner, fired.(part, _1)) }
        part.parts.any? ? own + edges(part, "#{prefix}#{name}_", "#{prefix}#{name}", &fired) : own
      end
    end

    def self.edge(from, wire, names, owner, fired)
      target = wire.target
      to, label = if names.key?(target) then [ names[target], "#{wire.output} → #{wire.input}" ]
      elsif target.is_a?(Proc) then [ owner, wire.output.to_s ]
      elsif target.is_a?(Foundation::Ports) then [ anonymous(target), "#{wire.output} → #{wire.input}" ]
      else [ anonymous(target), wire.output.to_s ]
      end
      fired ? "  #{from} -- #{label} --> #{to}" : "  #{from} -. #{label} .-> #{to}"
    end

    # An instance the composition made inline, drawn once per object, named by its class (`chart` renumbers it).
    def self.anonymous(target)
      owner, name = target.class.name.split("::").last(2)
      kind = name == "Port" ? "#{owner} port" : name
      "#{kind.downcase.delete('^a-z0-9')}_#{target.object_id}([#{kind}])"
    end
  end
end
