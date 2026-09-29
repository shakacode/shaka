# frozen_string_literal: true

require_relative 'test_helper'
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
end
