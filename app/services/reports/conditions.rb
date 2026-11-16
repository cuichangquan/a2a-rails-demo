# frozen_string_literal: true

module Reports
  # Application-owned interpretation of successive answers. The Gem never
  # merges arbitrary JSON or decides whether business criteria are authorized.
  class Conditions
    FIELDS = %w[year month department_id].freeze

    def self.combine(inputs)
      inputs.each_with_object({}) do |input, combined|
        unless input.is_a?(Hash) && (input.keys - FIELDS).empty? &&
            input.all? { |key, value| valid_value?(key, value) }
          raise SalesSummary::InvalidConditions, SalesSummary::ERROR_MESSAGE
        end
        # Only the explicitly allowed report fields are replaced by an answer.
        combined.merge!(input)
      end
    end

    def self.missing(criteria)
      FIELDS - criteria.keys
    end

    def self.valid_value?(key, value)
      return false unless value.is_a?(Integer)

      case key
      when "year" then (2000..2100).cover?(value)
      when "month" then (1..12).cover?(value)
      when "department_id" then value.positive?
      else false
      end
    end
    private_class_method :valid_value?
  end
end
