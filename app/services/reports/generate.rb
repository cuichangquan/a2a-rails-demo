# frozen_string_literal: true

module Reports
  # A2A boundary only. The business service below can also be called directly.
  class Generate
    def self.call(message:, context:)
      parts = message.fetch(:parts)
      unless parts.length == 1 && parts.first.key?(:data)
        raise A2A::Rails::RejectedTask, "Report requires exactly one Data Part."
      end
      SalesSummary.call(criteria: parts.first.fetch(:data))
    rescue SalesSummary::InvalidConditions
      # Fixed domain explanation: never echo arbitrary input or exception details.
      raise A2A::Rails::RejectedTask, SalesSummary::ERROR_MESSAGE
    end
  end
end
