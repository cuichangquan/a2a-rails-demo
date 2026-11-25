# frozen_string_literal: true
require "minitest/autorun"
require "a2a-rails"
require_relative "../app/services/reports/sales_summary"
require_relative "../app/services/reports/conditions"
require_relative "../app/services/reports/generate"

class GenerateTest < Minitest::Test
  def user(data)
    { role: :user, parts: [{ data: data }] }
  end

  def test_complete_input_retains_hash_result
    message = user("year" => 2026, "month" => 10, "department_id" => 123)
    result = Reports::Generate.call(message: message, context: {})
    assert_instance_of Hash, result
    assert_equal 35_000, result["total_amount"]
  end

  def test_missing_department_returns_explicit_gem_owned_result
    message = user("year" => 2026, "month" => 10)
    result = Reports::Generate.call(message: message, context: { history: [message] })
    assert_instance_of A2A::Rails::InputRequired, result
  end

  def test_agent_question_is_not_used_as_business_input
    initial = user("year" => 2026, "month" => 10)
    question = { role: :agent, parts: [{ text: "Question" }, { data: { "missing_fields" => ["department_id"] } }] }
    answer = user("department_id" => 123)
    result = Reports::Generate.call(message: answer, context: { history: [initial, question, answer] })
    assert_equal 3, result["sales_count"]
    assert_equal 35_000, result["total_amount"]
  end

  def test_struct_client_whole_float_values_support_question_and_answer
    initial = user("year" => 2026.0, "month" => 10.0)
    waiting = Reports::Generate.call(message: initial, context: { history: [initial] })
    assert_instance_of A2A::Rails::InputRequired, waiting

    question = { role: :agent, parts: [{ data: { "missing_fields" => ["department_id"] } }] }
    answer = user("department_id" => 123.0)
    result = Reports::Generate.call(message: answer, context: { history: [initial, question, answer] })
    assert_equal 3, result["sales_count"]
    assert_equal 35_000, result["total_amount"]
    assert_equal "JPY", result["currency"]
  end

  def test_invalid_month_remains_rejected_even_when_department_missing
    message = user("year" => 2026, "month" => 13)
    assert_raises(A2A::Rails::RejectedTask) { Reports::Generate.call(message: message, context: {}) }
  end

  def test_incomplete_answer_can_ask_again
    initial = user("year" => 2026)
    answer = user("month" => 10)
    result = Reports::Generate.call(message: answer, context: { history: [initial, answer] })
    assert_instance_of A2A::Rails::InputRequired, result
  end
end
