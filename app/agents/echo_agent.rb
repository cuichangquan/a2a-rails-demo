# frozen_string_literal: true
class EchoAgent < A2A::Rails::Agent
  name "Echo Agent"
  description "Rails A2A Echo and synthetic sales report examples"
  execution_mode :sync

  # Existing Router API selects a declared Skill; it is not authorization.
  router ->(message:, context:, skills:) {
    message.fetch(:parts).any? { |part| part.key?(:data) } ? :report : :reply
  }
  version "1.0"

  # Client text prefixed 'direct:' returns direct Message (no Task).
  # This is a response-shape choice, never an authorization decision.
  response_mode ->(message:) {
    parts = message.fetch(:parts)
    !parts.any? { |part| part.key?(:data) } &&
      parts.any? { |part| part[:text]&.start_with?("direct:") } ? :message : :task
  }

  skill :reply,
    description: "Echo text back to the caller",
    tags: %w[echo demo],
    handler: Echo::Reply

  skill :report,
    description: "Summarize fixed sales; ask for missing year, month or department",
    tags: %w[report demo],
    input_modes: ["application/json"],
    output_modes: ["application/json", "text/plain"],
    handler: Reports::Generate
end
