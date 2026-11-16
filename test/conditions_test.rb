# frozen_string_literal: true
require "minitest/autorun"
require_relative "../app/services/reports/sales_summary"
require_relative "../app/services/reports/conditions"

class ConditionsTest < Minitest::Test
  def test_partial_answers_combine_in_order_without_mutating_inputs
    initial = { "year" => 2026, "month" => 10 }.freeze
    answer = { "department_id" => 123 }.freeze
    result = Reports::Conditions.combine([initial, answer])
    assert_equal({ "year" => 2026, "month" => 10, "department_id" => 123 }, result)
    assert_empty Reports::Conditions.missing(result)
    assert_equal %w[department_id], Reports::Conditions.missing(initial)
    assert_equal 35_000, Reports::SalesSummary.call(criteria: result)["total_amount"]
  end

  def test_answer_can_remain_incomplete
    result = Reports::Conditions.combine([{ "year" => 2026 }, { "month" => 10 }])
    assert_equal %w[department_id], Reports::Conditions.missing(result)
    assert_equal %w[year month department_id], Reports::Conditions.missing(Reports::Conditions.combine([{}]))
  end

  def test_application_explicitly_allows_replacing_a_condition
    assert_equal 11, Reports::Conditions.combine([{ "month" => 10 }, { "month" => 11 }])["month"]
  end

  def test_invalid_values_are_rejected_before_asking_for_missing_fields
    [nil, [], { "month" => 13 }, { "month" => "10" }, { "year" => false },
      { "department_id" => nil }, { "department_id" => 0 }, { "extra" => 1 },
      { "month" => {} }, { "month" => [] }].each do |input|
      assert_raises(Reports::SalesSummary::InvalidConditions) { Reports::Conditions.combine([input]) }
    end
  end
end
