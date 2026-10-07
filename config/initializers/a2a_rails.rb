# frozen_string_literal: true
A2A::Rails.configure do |config|
  config.agent = "EchoAgent"
  # Development/test loopback only. Do not expose without host authentication.
end
