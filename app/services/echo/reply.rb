# frozen_string_literal: true
module Echo
  class Reply
    def self.call(message:, context:)
      text = message.fetch(:parts).filter_map { |part| part[:text] }.join("\n")
      "Echo: #{text}"
    end
  end
