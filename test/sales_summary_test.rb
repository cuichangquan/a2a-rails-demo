# frozen_string_literal: true
require "minitest/autorun"
require_relative "../app/services/reports/sales_summary"

class SalesSummaryTest < Minitest::Test
  def criteria = { "year" => 2026, "month" => 10, "department_id" => 123 }

  def test_exact_shared_fixture
    assert_equal criteria.merge("sales_count" => 3, "total_amount" => 35_000, "currency" => "JPY"),
      Reports::SalesSummary.call(criteria: criteria)
  end

  def test_each_filter_excludes_other_rows
    { { "month" => 9 } => 7_000, { "department_id" => 456 } => 9_000,
      { "year" => 2025 } => 11_000 }.each do |change, amount|
      result = Reports::SalesSummary.call(criteria: criteria.merge(change))
      assert_equal 1, result.fetch("sales_count")
      assert_equal amount, result.fetch("total_amount")
    end
  end

  def test_empty_report_is_a_valid_business_result
    result = Reports::SalesSummary.call(criteria: criteria.merge("month" => 1))
    assert_equal 0, result.fetch("sales_count")
    assert_equal 0, result.fetch("total_amount")
  end

  def test_invalid_conditions
    [{ "month" => 13 }, { "month" => 0 }, { "year" => 1999 },
      { "department_id" => 0 }, { "month" => "10" }, { "extra" => true }].each do |change|
      assert_raises(Reports::SalesSummary::InvalidConditions) do
        Reports::SalesSummary.call(criteria: criteria.merge(change))
      end
    end
    assert_raises(Reports::SalesSummary::InvalidConditions) do
      Reports::SalesSummary.call(criteria: criteria.reject { |key, _| key == "month" })
    end
  end

  def test_does_not_modify_the_callers_conditions
    input = criteria.freeze
    Reports::SalesSummary.call(criteria: input)
    assert_equal criteria, input
  end
end
