# frozen_string_literal: true

module Reports
  # Ordinary Rails business service: no A2A/SDK objects, network or database.
  class SalesSummary
    class InvalidConditions < ArgumentError; end

    SALES = [
      { "year" => 2026, "month" => 10, "department_id" => 123, "amount" => 12_000 },
      { "year" => 2026, "month" => 10, "department_id" => 123, "amount" => 18_000 },
      { "year" => 2026, "month" => 10, "department_id" => 123, "amount" => 5_000 },
      { "year" => 2026, "month" => 9, "department_id" => 123, "amount" => 7_000 },
      { "year" => 2026, "month" => 10, "department_id" => 456, "amount" => 9_000 },
      { "year" => 2025, "month" => 10, "department_id" => 123, "amount" => 11_000 }
    ].map(&:freeze).freeze
    FIELDS = %w[year month department_id].freeze
    ERROR_MESSAGE = "Report conditions require integer year (2000..2100), month (1..12), and positive department_id; no other fields."

    def self.call(criteria:)
      valid = criteria.is_a?(Hash) && criteria.keys.length == FIELDS.length &&
        FIELDS.all? { |field| criteria[field].is_a?(Integer) } &&
        (2000..2100).cover?(criteria["year"]) && (1..12).cover?(criteria["month"]) &&
        criteria["department_id"].positive?
      raise InvalidConditions, ERROR_MESSAGE unless valid

      matches = SALES.select do |sale|
        FIELDS.all? { |field| sale.fetch(field) == criteria.fetch(field) }
      end
      criteria.slice(*FIELDS).merge("sales_count" => matches.length,
        "total_amount" => matches.sum { |sale| sale.fetch("amount") }, "currency" => "JPY")
    end
  end
end
