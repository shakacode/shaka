# frozen_string_literal: true

require_relative 'test_helper'
require 'bundler'
require 'yaml'

class LintToolingTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def test_rubocop_loads_minitest_and_performance_departments
    %w[Minitest/AssertEmpty Performance/StringReplacement].each do |cop|
      output, status = show_cops(cop)
      assert status.success?, output
      assert_includes output, "#{cop}:\n"
    end
  end

  def test_dependabot_schedules_bundler_updates_at_the_repository_root
    updates = YAML.safe_load_file(File.join(ROOT, '.github', 'dependabot.yml')).fetch('updates')
    bundler = updates.find { |update| update['package-ecosystem'] == 'bundler' }

    refute_nil bundler, 'Dependabot must include a bundler ecosystem'
    assert_equal '/', bundler.fetch('directory')
    assert_equal 'weekly', bundler.fetch('schedule').fetch('interval')
  end

  private

  def show_cops(cop)
    Bundler.with_unbundled_env do
      Open3.capture2e(
        { 'BUNDLE_GEMFILE' => File.join(ROOT, 'Gemfile') },
        'bundle', 'exec', 'rubocop', '--show-cops', cop,
        chdir: ROOT
      )
    end
  end
end
