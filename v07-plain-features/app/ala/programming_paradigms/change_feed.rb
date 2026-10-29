module ProgrammingParadigms
  # Outside change as a paradigm (§2.2; the observer kept inside it, §4.4.2): a change made in one
  # session reaching the pages open in others. The composition making the change pushes a fact into
  # a `Publish` sink; a page places a `Subscription`, configured with the topic and the kinds it
  # listens to, and wires each kind as an output. What travels is a fact keyed by identity, never HTML;
  # this module owns its format, so the two ends share only the topic, the kind and the identity key.
  #
  # A page is rebuilt per request, so delivery is the browser's `change-feed` controller: it subscribes
  # to the topic through `Channel` and posts each fact of a listened kind to the page's live URL, where
  # the page's screen takes it as `live(message)` and answers with the patches its arms made.
  module ChangeFeed
    def self.encode(kind, fields) = { "kind" => kind.to_s, **fields.transform_keys(&:to_s) }
    def self.decode(message) = message.to_h.transform_keys(&:to_sym).then { [ _1[:kind].to_s, _1.except(:kind) ] }

    # The publish sink. Config: topic, kind, fields (a lambda of the payload giving the fact's
    # identity-keyed fields; the payload itself by default), cable. In: push (the payload).
    class Publish
      def push(payload) = (@cable.broadcast(@topic, ChangeFeed.encode(@kind, @fields.(payload))); nil)

      def initialize(topic:, kind:, fields: ->(payload) { payload }, cable: ActionCable.server)
        @topic, @kind, @fields, @cable = topic, kind, fields, cable
      end
    end

    # The subscribe part. Config: topic, kinds (its outputs), url (where the page takes a fact).
    # In: receive (a fact as it arrived). Out: one per kind, the fact's fields.
    class Subscription
      attr_reader :kinds
      alias outputs kinds

      def receive(message)
        kind, fields = ChangeFeed.decode(message)
        @kinds.select { _1.to_s == kind }.to_h { [ _1, fields ] }
      end

      # what the page's feed element carries for the browser's `change-feed` controller
      def attributes = { controller: "change-feed", change_feed_topic_value: Turbo.signed_stream_verifier.generate(@topic), change_feed_kinds_value: @kinds, change_feed_url_value: @url }

      def initialize(topic:, kinds:, url:) = (@topic, @kinds, @url = topic, kinds, url)
    end

    # Topics are signed in the page, as Turbo's stream names are, so a page can't listen to another
    # session's checkout.
    class Channel < ActionCable::Channel::Base
      def subscribed
        topic = Turbo.signed_stream_verifier.verified(params[:topic])
        topic ? stream_from(topic) : reject
      end
    end
  end
end
