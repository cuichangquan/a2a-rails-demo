# frozen_string_literal: true
class EchoAgent < A2A::Rails::Agent
  name "Echo Agent"
  description "Minimal Rails A2A JSON-RPC v1.0 Echo Agent"
  version "1.0"

  # Client text prefixed 'direct:' returns direct Message (no Task).
  # This is a response-shape choice, never an authorization decision.
  response_mode ->(message:) {
    message.fetch(:parts).any? { |part| part[:text]&.start_with?("direct:") } ? :message : :task
  }

  skill :reply,
    description: "Echo text back to the caller",
    tags: %w[echo demo],
    handler: Echo::Reply
end
