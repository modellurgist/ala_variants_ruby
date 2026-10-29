require "test_helper"

# The ChangeFeed paradigm's two parts on their ports, and the one fact format they share.
class ChangeFeedTest < ActiveSupport::TestCase
  ChangeFeed = ProgrammingParadigms::ChangeFeed

  Recorder = Struct.new(:got) do
    include Foundation::Ports
    input(:input, ProgrammingParadigms::DataFlow) { |x| (self.got ||= []) << x }
  end

  def feed = ChangeFeed::Subscription.new(topic: "catalog", kinds: %i[stock product])

  test "a feed's outputs are the kinds it was configured with" do
    assert_equal %i[stock product], feed.unwired_outputs
    assert_equal({ topic: "catalog", kinds: %i[stock product] }, feed.subscription)
  end

  test "a feed hands a fact of a kind it listens to to that kind's port, and drops the rest" do
    f = feed.wire_to(stock = Recorder.new, from: :stock).wire_to(product = Recorder.new, from: :product)
    f.input_port(:receive).push(kind: "stock", fact: { product_id: 7, stock: 2 })
    f.input_port(:receive).push(kind: "price", fact: { product_id: 7, amount: 900 })
    assert_equal [ { product_id: 7, stock: 2 } ], stock.got
    assert_nil product.got
  end

  test "what a publisher sends is what a page's post back reads: a kind and an identity-keyed fact, no markup" do
    message = Nokogiri::HTML5.fragment(ChangeFeed.message(:stock, { product_id: 7, stock: 2 })).at("turbo-stream")
    assert_equal [ "change_feed", "" ], [ message["action"], message.inner_html ]
    assert_equal({ kind: "stock", fact: { product_id: 7, stock: 2 } }, ChangeFeed.read(message["kind"], message["fact"]))
  end

  test "a publish sink sends one fact per push on its topic, built by its fact lambda" do
    sink = ChangeFeed::Publish.new(topic: "checkout_9", kind: :outcome, fact: ->(_) { { cart_id: 9, step: :complete } })
    sent = capture_turbo_stream_broadcasts("checkout_9") { sink.input_port(:push).push("ch_1") }
    assert_equal [ [ "outcome", { "cart_id" => 9, "step" => "complete" } ] ], sent.map { [ _1["kind"], JSON.parse(_1["fact"]) ] }
  end
end
