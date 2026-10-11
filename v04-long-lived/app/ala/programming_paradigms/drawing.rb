module ProgrammingParadigms
  # Draws a built composition as a Mermaid flowchart by walking its object graph (R8: the picture
  # can't drift from the code). A node per part the composition names, an edge per wire labelled
  # `output → input`; an output wired to a block lands on the composition itself, and an instance or
  # port the composition made inline (a sink, a job's port) is drawn by what it is.
  module Drawing
    def self.mermaid(screen)
      names = screen.parts.to_h { |name, part| [ part, name.to_s ] }
      edges = screen.parts.flat_map { |name, part| part.wires.map { edge(name, _1, names, screen) } }
      ([ "flowchart LR", "  screen[[#{screen.class.name}]]" ] + screen.parts.map { |name, part| "  #{name}[#{name}: #{part.class.name.split('::').last}]" } + edges.uniq).join("\n") + "\n"
    end

    def self.edge(from, wire, names, screen)
      target = wire.target
      to, label = if names.key?(target) then [ names[target], "#{wire.output} → #{wire.input}" ]
      elsif target.is_a?(Proc) then [ "screen", wire.output.to_s ]
      elsif target.is_a?(Foundation::Ports) then [ anonymous(target), "#{wire.output} → #{wire.input}" ]
      else [ anonymous(target), wire.output.to_s ]
      end
      "  #{from} -- #{label} --> #{to}"
    end

    # An instance the composition made inline, drawn once per object, named by its class.
    def self.anonymous(target)
      owner, name = target.class.name.split("::").last(2)
      kind = name == "Port" ? "#{owner} port" : name
      "#{kind.downcase.delete('^a-z0-9')}_#{target.object_id}([#{kind}])"
    end
  end
end
