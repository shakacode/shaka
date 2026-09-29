# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'rbconfig'

class JevCommandTest < Minitest::Test
  def test_missing_options_and_unreadable_file_have_clean_errors
    command = [RbConfig.ruby, File.expand_path('../skills/shaka-jev/scripts/analyze', __dir__),
               '--pr-url', 'https://github.com/shakacode/shaka/pull/302', '--head', 'a' * 40]
    missing, missing_status = Open3.capture2e(*command)
    unreadable, unreadable_status = Open3.capture2e(*command, '--evidence', '/no/such/evidence-file')

    refute_predicate missing_status, :success?
    refute_predicate unreadable_status, :success?
    assert_match(/shaka-jev:/, missing)
    assert_match(/shaka-jev:/, unreadable)
    refute_match(/in ['`]/, unreadable)
  end

  def test_missing_api_key_has_clean_error_before_network_access
    command = [RbConfig.ruby, File.expand_path('../skills/shaka-jev/scripts/analyze', __dir__),
               '--pr-url', 'https://github.com/shakacode/shaka/pull/302', '--head', 'a' * 40,
               '--evidence', __FILE__]
    output, status = Open3.capture2e({ 'TYPESAFE_API_KEY' => nil }, *command)

    refute_predicate status, :success?
    assert_match(/TYPESAFE_API_KEY is required/, output)
  end
end
