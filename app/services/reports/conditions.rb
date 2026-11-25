# frozen_string_literal: true

module Reports
  # Application-owned interpretation of successive answers. The Gem never
  # merges arbitrary JSON or decides whether business criteria are authorized.
  class Conditions
    FIELDS = %w[year month department_id].freeze
    MAX_SAFE_JSON_INTEGER = (2**53) - 1

    def self.combine(inputs)
      inputs.each_with_object({}) do |input, combined|
        unless input.is_a?(Hash) && (input.keys - FIELDS).empty?
          raise SalesSummary::InvalidConditions, SalesSummary::ERROR_MESSAGE
        end

        normalized = input.transform_values { |value| normalize_number(value) }
        unless normalized.all? { |key, value| valid_value?(key, value) }
          raise SalesSummary::InvalidConditions, SalesSummary::ERROR_MESSAGE
        end
        # Only the explicitly allowed report fields are replaced by an answer.
        combined.merge!(normalized)
      end
    end

    def self.missing(criteria)
      FIELDS - criteria.keys
    end

    # Protobuf Struct clients such as the Python A2A SDK can emit 10.0 for 10.
    # Convert only whole Float values in the interoperable integer range;
    # leave everything else to the existing type and field-specific checks.
    def self.normalize_number(value)
      return value unless value.is_a?(Float) && value.finite? && value.abs <= MAX_SAFE_JSON_INTEGER

      integer = value.to_i
      value == integer ? integer : value
    end
    private_class_method :normalize_number

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
