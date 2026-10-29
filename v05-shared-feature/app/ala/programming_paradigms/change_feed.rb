module ProgrammingParadigms
  # Outside change, as a paradigm (§4.4.2: the subscriber does not know the publisher). A composition
  # that makes a change wires it to a `Publish` sink; a page that shows it places a `Subscription` and wires
  # the feed's kinds to the parts that care. What travels on the topic is a fact: a kind and values
  # keyed by identity ({ product_id:, stock: }), never HTML. This module owns that format at both ends.
  # In the browser, `change_feed_controller.js` reads the fact and posts it back to the page's own
  # refresh URL, whose controller pushes it into the page's composition and answers with what changed.
  module ChangeFeed
    def self.message(kind, fact) = ActionController::Base.helpers.tag.turbo_stream(action: "change_feed", kind:, fact: fact.to_json)
    def self.read(kind, fact) = { kind: kind.to_s, fact: JSON.parse(fact.to_s, symbolize_names: true) }

    # Config: topic, kind, fact (a lambda of the payload giving the identity-keyed fact). In: push.
    class Publish
      include Foundation::Ports

      input(:push, ProgrammingParadigms::DataFlow) { |payload| Turbo::StreamsChannel.broadcast_stream_to(@topic, content: ChangeFeed.message(@kind, @fact.(payload))) }

      def initialize(topic:, kind:, fact:) = (@topic, @kind, @fact = topic, kind, fact)
    end

    # The page's subscription. Config: topic, kinds (the fact kinds the page listens to; each is an
    # output). In: receive ({ kind:, fact: }, as `ChangeFeed.read` decodes it). Out: one per kind, the fact.
    class Subscription
      include Foundation::Ports

      input(:receive, ProgrammingParadigms::DataFlow) do |message|
        kind = @kinds.find { _1.to_s == message[:kind] }
        emit(kind, message[:fact]) if kind
      end

      def initialize(topic:, kinds:) = (@topic, @kinds = topic, kinds)
      def outputs = @kinds.to_h { [ _1, { paradigm: ProgrammingParadigms::DataFlow, many: true } ] }
      def subscription = { topic: @topic, kinds: @kinds }
    end

    # Places a feed on a page: the topic's stream and the element the browser half runs on.
    module Helper
      def change_feed(subscription, url:)
        safe_join([ turbo_stream_from(subscription[:topic]), tag.div(data: { controller: "change-feed", change_feed_kinds_value: subscription[:kinds].to_json, change_feed_url_value: url }) ])
      end
    end
  end
end
