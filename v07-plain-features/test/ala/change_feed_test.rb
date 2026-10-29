require "test_helper"

# The ChangeFeed paradigm's own ports, without a page: a fact pushed into a sink is what a feed listening
# for its kind puts out, and nothing else reaches it.
class ChangeFeedTest < ActiveSupport::TestCase
  ChangeFeed = ProgrammingParadigms::ChangeFeed

  class Cable
    attr_reader :sent

    def initialize = @sent = []
    def broadcast(topic, message) = @sent << [ topic, message ]
  end

  # what a fact looks like after Action Cable and a JSON post carried it
  def carried(message) = JSON.parse(message.to_json)

  def feed(kinds) = ChangeFeed::Subscription.new(topic: "t", kinds:, url: "/live")

  test "a sink sends its kind and the payload's fields to its topic" do
    cable = Cable.new
    ChangeFeed::Publish.new(topic: "catalog", kind: :stock, cable:).push({ product_id: 7, stock: 3 })
    assert_equal [ [ "catalog", { "kind" => "stock", "product_id" => 7, "stock" => 3 } ] ], cable.sent
  end

  test "a sink's fields lambda picks the identity from its payload" do
    cable = Cable.new
    ChangeFeed::Publish.new(topic: "catalog", kind: :product_changed, fields: ->(p) { { product_id: p[:id] } }, cable:).push({ id: 7, name: "W" })
    assert_equal({ "kind" => "product_changed", "product_id" => 7 }, cable.sent.dig(0, 1))
  end

  test "a feed puts out a fact of a kind it listens to on that kind's port, with the fact's fields" do
    cable = Cable.new
    ChangeFeed::Publish.new(topic: "t", kind: :stock, cable:).push({ product_id: 7, stock: 0 })
    assert_equal({ stock: { product_id: 7, stock: 0 } }, feed(%i[stock price]).receive(carried(cable.sent.dig(0, 1))))
  end

  test "a feed drops a kind it does not listen to, and a message with no kind" do
    assert_empty feed(%i[stock]).receive(carried(ChangeFeed.encode(:price, { product_id: 7, amount: 5 })))
    assert_empty feed(%i[stock]).receive({ "product_id" => 7 })
  end

  test "a feed's outputs are its kinds, and its element carries them, its URL and a signed topic" do
    attributes = feed(%i[stock paid]).attributes
    assert_equal %i[stock paid], feed(%i[stock paid]).outputs
    assert_equal [ "change-feed", %i[stock paid], "/live" ], attributes.values_at(:controller, :change_feed_kinds_value, :change_feed_url_value)
    assert_equal "t", Turbo.signed_stream_verifier.verified(attributes[:change_feed_topic_value])
  end
end

class ChangeFeedChannelTest < ActionCable::Channel::TestCase
  tests ProgrammingParadigms::ChangeFeed::Channel

  test "subscribes to a signed topic" do
    subscribe topic: Turbo.signed_stream_verifier.generate("checkout_1")
    assert subscription.confirmed?
    assert_has_stream "checkout_1"
  end

  test "rejects a topic it did not sign" do
    subscribe topic: "checkout_1"
    assert subscription.rejected?
  end
end
