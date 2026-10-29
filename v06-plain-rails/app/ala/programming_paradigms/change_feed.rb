module ProgrammingParadigms
  # Outside change as a paradigm (§2.2; the observer kept inside it, §4.4.2): a composition that makes a
  # change wires it to a Publish sink, and a page that shows it places a Subscription. Both are configured
  # with a topic; they share only it and the fact, a kind plus identity keys ({ product_id:, stock: }),
  # never HTML. A page is rebuilt per request, so a fact the page listens to refreshes it, and its screen
  # reads the current values through its configured tables. ChangeFeed owns the fact's format and who hears it.
  module ChangeFeed
    def self.fact(kind, keys) = { "kind" => kind.to_s, **keys.transform_keys(&:to_s) }
    def self.hears?(fact, kinds:, match: {}) = kinds.map(&:to_s).include?(fact["kind"]) && match.all? { |key, value| fact[key.to_s] == value }

    # A sink. Config: topic, kind. In: push (the identity keys of what changed).
    class Publish
      def push(keys)
        ActionCable.server.broadcast(@topic, ChangeFeed.fact(@kind, keys))
        nil
      end

      def initialize(topic:, kind:) = (@topic, @kind = topic, kind)
    end

    # What a page listens to, rendered as the element the `change-feed` Stimulus controller subscribes from.
    # Config: topic, kinds, match (keys a fact must carry), catch_up (refresh on every subscription, for a
    # page whose fact can be sent before it listens).
    class Subscription
      def initialize(topic:, kinds:, match: {}, catch_up: false) = (@topic, @kinds, @match, @catch_up = topic, kinds, match, catch_up)

      def only(**match) = Subscription.new(topic: @topic, kinds: @kinds, match:, catch_up: @catch_up)

      def render_in(view)
        view.tag.div(hidden: true, data: { controller: "change-feed", change_feed_topic_value: Channel.signed_stream_name(@topic),
                                           change_feed_kinds_value: @kinds, change_feed_match_value: @match, change_feed_catch_up_value: @catch_up })
      end
    end

    # Delivers to a subscriber only the facts its feed hears; the topic is signed as Turbo signs a stream.
    class Channel < ActionCable::Channel::Base
      extend Turbo::Streams::StreamName

      def subscribed
        topic = self.class.verified_stream_name(params[:signed_topic]) or return reject
        kinds, match = Array(params[:kinds]), params[:match].to_h
        stream_from(topic, coder: ActiveSupport::JSON) { |fact| transmit(fact) if ChangeFeed.hears?(fact, kinds:, match:) }
      end
    end
  end
end
