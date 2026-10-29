require "test_helper"

class ChangeFeedTest < ActiveSupport::TestCase
  ChangeFeed = ProgrammingParadigms::ChangeFeed

  test "a fact is its kind and the identity keys of what changed, as it travels" do
    assert_equal({ "kind" => "stock", "product_id" => 7, "stock" => 2 }, ChangeFeed.fact(:stock, product_id: 7, stock: 2))
  end

  test "a feed hears the kinds it lists, and only facts carrying the keys it matches" do
    stock = ChangeFeed.fact(:stock, product_id: 7, stock: 2)
    assert ChangeFeed.hears?(stock, kinds: %i[stock product])
    assert_not ChangeFeed.hears?(stock, kinds: %i[product])
    assert ChangeFeed.hears?(stock, kinds: %i[stock], match: { product_id: 7 })
    assert ChangeFeed.hears?(stock, kinds: %i[stock], match: { "product_id" => 7 })
    assert_not ChangeFeed.hears?(stock, kinds: %i[stock], match: { product_id: 8 })
  end

  test "publish sends the fact on its topic and answers nothing to route" do
    sink = ChangeFeed::Publish.new(topic: "shop", kind: :product)
    assert_nil sink.push(product_id: 3)
    assert_equal [ { "kind" => "product", "product_id" => 3 } ], broadcasts("shop").map { JSON.parse(_1) }
  end

  test "a feed renders the element the page subscribes from, its topic signed; only narrows it to one identity" do
    html = ChangeFeed::Subscription.new(topic: "shop", kinds: %i[stock product], catch_up: true).only(product_id: 3).render_in(ApplicationController.new.view_context)
    element = Nokogiri::HTML5.fragment(html).at("[data-controller=change-feed]")
    assert_equal "shop", ChangeFeed::Channel.verified_stream_name(element["data-change-feed-topic-value"])
    assert_equal [ "stock", "product" ], JSON.parse(element["data-change-feed-kinds-value"])
    assert_equal({ "product_id" => 3 }, JSON.parse(element["data-change-feed-match-value"]))
    assert_equal "true", element["data-change-feed-catch-up-value"]
  end
end

class ChangeFeedChannelTest < ActionCable::Channel::TestCase
  tests ProgrammingParadigms::ChangeFeed::Channel

  test "a subscription with a signed topic streams from it" do
    subscribe signed_topic: ProgrammingParadigms::ChangeFeed::Channel.signed_stream_name("shop"), kinds: [ "stock" ]
    assert subscription.confirmed?
    assert_has_stream "shop"
  end

  test "an unsigned topic is rejected" do
    subscribe signed_topic: "shop", kinds: [ "stock" ]
    assert subscription.rejected?
  end
end
