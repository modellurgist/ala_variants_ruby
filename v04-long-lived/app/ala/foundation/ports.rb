module Foundation
  # Ports and wiring for ALA classes (Spray §2.3.4, §7.2.6). A class declares `output` ports (where it
  # sends) and `input` ports (what it receives); only the layer above connects them, with `wire_to`,
  # `wire_in` or `on`. Port methods never join a class's public interface: an input's handler is
  # private, and an output is a private instance variable the wiring fills.
  module Ports
    def self.included(base) = base.extend(ClassMethods)

    module ClassMethods
      def outputs = (@outputs ||= {})
      def inputs  = (@inputs ||= {})

      # An accepted port: a private ivar the wiring fills. `many: true` allows fan-out.
      def output(name, paradigm, many: false) = outputs[name] = { paradigm:, many: }

      # A provided port: the paradigm builds the port object; the handler stays private.
      def input(name, paradigm, &handler)
        inputs[name] = paradigm
        define_method(:"#{name}_received", &handler)
        private :"#{name}_received"
      end
    end

    # Wires one of my outputs to one of target's inputs, by port name or by the only paradigm match.
    # The target may also be a bare port object (one a paradigm or an execution model built).
    def wire_to(target, from: nil, to: nil)
      return attach(from, self.class.outputs.fetch(from), target, target).then { self } unless target.respond_to?(:input_port)
      out, spec = find_output(from, target, to)
      input = to || target.class.inputs.key(spec[:paradigm])
      attach(out, spec, target.input_port(input), target, input)
      self
    end

    def wire_in(target, **) = wire_to(target, **).then { target }

    # Wires an output to a block: Spray's lambda at the wire (§6.17.4), for adapting or for a sink the
    # composition writes inline.
    def on(from, &block)
      spec = self.class.outputs.fetch(from) { raise ArgumentError, "#{self.class} has no output #{from.inspect}" }
      attach(from, spec, spec[:paradigm].port(&block), block)
      self
    end

    def input_port(name)
      paradigm = self.class.inputs.fetch(name) { raise ArgumentError, "#{self.class} has no input #{name.inspect}" }
      paradigm.port(&method(:"#{name}_received"))
    end

    # Outputs nothing is wired to yet; a composition test lists them.
    def unwired_outputs = self.class.outputs.keys.select { instance_variable_get(:"@#{_1}").nil? }

    # Every wire made from my outputs, in wiring order: what a drawing of the built graph reads.
    Wire = Data.define(:output, :target, :input)
    def wires = @wires || []

    private

    # Send on an output port; an unwired port is inert (§6.15), a fan-out port delivers in wiring order.
    def emit(name, payload = nil)
      Array(instance_variable_get(:"@#{name}")).each { _1.call(payload) }
      nil
    end

    # Ask on a request/response output port; it must be wired.
    def ask(name, query = nil)
      port = instance_variable_get(:"@#{name}") or raise "#{self.class}.#{name} is not wired"
      port.call(query)
    end

    def attach(out, spec, port, target = nil, input = nil)
      (@wires ||= []) << Wire.new(output: out, target:, input:)
      if spec[:many]
        (instance_variable_get(:"@#{out}") || instance_variable_set(:"@#{out}", [])) << port
      else
        instance_variable_set(:"@#{out}", port)
      end
    end

    def find_output(from, target, to)
      wanted = to ? [ target.class.inputs.fetch(to) ] : target.class.inputs.values
      candidates = self.class.outputs.select do |name, spec|
        (from.nil? || name == from) && wanted.include?(spec[:paradigm]) &&
          (spec[:many] || instance_variable_get(:"@#{name}").nil?)
      end
      candidates.first or raise ArgumentError, "can't wire #{self.class}#{from && ".#{from}"} to #{target.class}#{to && ".#{to}"}"
    end
  end
end
