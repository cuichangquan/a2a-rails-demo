# frozen_string_literal: true

module Reports
  # A2A boundary only. The business service below can also be called directly.
  class Generate
    def self.call(message:, context:)
      # History includes the current message. Select user inputs, never agent
      # questions. Merging is this application's explicit business policy.
      history = context.fetch(:history) { [message] }
      inputs = history.select { |entry| entry[:role].to_s == "user" }.map do |entry|
        parts = entry.fetch(:parts)
        unless parts.length == 1 && parts.first.key?(:data)
          raise A2A::Rails::RejectedTask, "Report requires exactly one Data Part."
        end
        parts.first.fetch(:data)
      end
      criteria = Conditions.combine(inputs)
      missing = Conditions.missing(criteria)
      unless missing.empty?
        # Fixed field names only, never arbitrary user values in the question.
        return A2A::Rails::InputRequired.new("Please provide: #{missing.join(', ')}.",
          data: { "missing_fields" => missing })
      end
      SalesSummary.call(criteria: criteria)
    rescue SalesSummary::InvalidConditions
      # Fixed domain explanation: never echo arbitrary input or exception details.
      raise A2A::Rails::RejectedTask, SalesSummary::ERROR_MESSAGE
    end
  end
end
