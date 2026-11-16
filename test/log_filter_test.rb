# frozen_string_literal: true
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "minitest/autorun"

class LogFilterTest < Minitest::Test
  def test_original_and_answer_messages_are_redacted_from_rails_parameters
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    params = { "params" => { "message" => { "parts" => [{ "data" => { "private_answer" => "hidden" } }] } } }
    result = filter.filter(params.merge("api" => params))
    assert_equal "[FILTERED]", result.dig("params", "message")
    assert_equal "[FILTERED]", result.dig("api", "params", "message")
    refute_includes result.inspect, "private_answer"
    refute_includes result.inspect, "hidden"
  end
end
