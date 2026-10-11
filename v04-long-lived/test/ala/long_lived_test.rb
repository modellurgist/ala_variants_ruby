require "test_helper"

# The execution model for compositions kept across requests: one instance per key, one thread at
# a time, reloaded when the store's stamp moved behind its back.
class LongLivedTest < ActiveSupport::TestCase
  class Composition
    include Foundation::Ports
    attr_reader :log
    input(:load, ProgrammingParadigms::Event) { @log << :load }
    input(:begin, ProgrammingParadigms::Event) { @log << :begin }
    input(:work, ProgrammingParadigms::DataFlow) { |ms| sleep(ms / 1000.0); @log << Thread.current.object_id }
    def initialize = @log = []
  end

  def registry(capacity: 1000) = ProgrammingParadigms::LongLived.new(build: ->(_key) { Composition.new }, version: ->(key) { @versions[key] }, begin: :begin, capacity:)
  setup { @versions = Hash.new(0) }

  test "the same instance serves a key's requests, loaded once and begun each time" do
    r = registry
    first = r.with(:a) { _1 }
    second = r.with(:a) { _1 }
    assert_same first, second
    assert_equal %i[load begin begin], first.log
  end

  test "a version that moved outside a request reloads the instance before its next use" do
    r = registry
    c = r.with(:a) { _1 }
    @versions[:a] += 1
    r.with(:a) { _1 }
    assert_equal %i[load begin load begin], c.log
  end

  test "a version moved by the request itself is not stale" do
    r = registry
    c = r.with(:a) { @versions[:a] += 1; _1 }
    r.with(:a) { _1 }
    assert_equal %i[load begin begin], c.log
  end

  test "two threads on one key take turns; two keys run at once" do
    r = registry
    c = r.with(:a) { _1 }
    threads = 2.times.map { Thread.new { r.with(:a) { _1.input_port(:work).push(20) } } }
    threads.each(&:join)
    assert_equal 2, c.log.count { _1.is_a?(Integer) }
    started = Time.now
    [ :b, :c ].map { |k| Thread.new { r.with(k) { _1.input_port(:work).push(100) } } }.each(&:join)
    assert_operator Time.now - started, :<, 0.19
  end

  test "beyond capacity the oldest key is dropped and rebuilt on its next request" do
    r = registry(capacity: 2)
    a = r.with(:a) { _1 }
    r.with(:b) { _1 }
    r.with(:c) { _1 }
    refute r.held?(:a)
    refute_same a, r.with(:a) { _1 }
  end
end
