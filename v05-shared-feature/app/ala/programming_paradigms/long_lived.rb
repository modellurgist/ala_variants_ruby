module ProgrammingParadigms
  # An execution model for compositions that outlive a request (§3.11.3: wired once, then run), on a
  # server that handles requests on several threads. One instance per key is kept in this process
  # and a request runs under that instance's own lock, so each stateful instance is used by one
  # thread at a time (§3.9), decided here and never inside a class (§3.10.2: the arbitrator). A
  # `version` lambda answers the store's stamp for the key, read once as a request starts and kept as
  # seen: any bump after that read, the request's own or another writer's, makes the next request
  # `reload` first. A lambda cannot tell whose a bump was, so none is taken as already seen.
  # `begin`, if given, is the input that opens a request. Config: build (a lambda of the key),
  # version (a lambda of the key), reload and begin (input names), capacity (keys kept).
  class LongLived
    Entry = Struct.new(:instance, :lock, :seen)

    # The registries an application keeps, by name: what a job names to reach a kept composition.
    # ala:accept r2 -- the table of kept compositions is process-wide by nature; the execution model is where that lives (§3.10.2)
    def self.register(name, **) = (@named ||= {})[name] = new(**)
    def self.named(name) = @named.fetch(name)
    def self.clear_all = (@named || {}).each_value(&:clear)

    def initialize(build:, version:, capacity:, reload: :load, begin: nil)
      @build, @version, @reload, @begin, @capacity = build, version, reload, binding.local_variable_get(:begin), capacity
      @entries = {}
      # ala:accept r4 -- this execution model is the arbitrator (§3.10.2): the locks are decided here, where instances are kept
      @lock = Mutex.new
    end

    # Runs the block with the composition for `key`, built on first use, reloaded when stale.
    def with(key)
      entry = @lock.synchronize { @entries[key] ||= admit(key) }
      entry.lock.synchronize do
        current = @version.(key)
        entry.instance.input_port(@reload).send_event if entry.seen != current
        entry.seen = current
        entry.instance.input_port(@begin).send_event if @begin
        yield entry.instance
      end
    end

    def size = @entries.size
    def held?(key) = @entries.key?(key)
    def clear = @lock.synchronize { @entries.clear }

    private

    # the oldest key goes when the table is full: a cart not seen for a while is rebuilt on its next request
    def admit(key)
      @entries.shift if @entries.size >= @capacity
      # ala:accept r4 -- one lock per kept instance, decided here as above
      Entry.new(@build.(key), Mutex.new, nil)
    end
  end
end
