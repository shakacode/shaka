# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'opening_check_test_helpers'
require_relative '../skills/shaka/lib/shaka/opening_check'

class OpeningCheckProvidersTest < Minitest::Test
  include OpeningCheckTestHelpers

  def test_codex_can_parse_the_opening
    with_claude(nil) do |root, _trace, bin|
      output = JSON.generate(parse('shaka merge', false))
      write_model(bin, 'codex', "File.write(ARGV[ARGV.index('-o') + 1], #{output.inspect})")
      assert_equal 'flagged', check('`shaka merge` checks the head.', root:, reviewer: 'openai/codex').fetch('status')
    end
  end

  def test_grok_can_parse_the_opening_without_a_pinned_model
    with_claude(nil) do |root, _trace, bin|
      output = JSON.generate(parse('Pull requests', true))
      write_model(bin, 'grok', "puts #{output.inspect}")
      assert_equal 'passed', check('Pull requests show the outcome.', root:, reviewer: 'xai/grok').fetch('status')
    end
  end

  def test_accepts_a_json_fence_from_claude
    output = JSON.generate(parse('Pull requests', true))
    body = "puts JSON.generate(result: #{"```json\n#{output}\n```".inspect})"
    with_claude(nil, body:) do |root, _trace|
      assert_equal 'passed', check('Pull requests show the outcome.', root:).fetch('status')
    end
  end

  def test_temporary_directory_inside_checkout_skips_the_cli
    with_claude(parse('shaka merge', false)) do |root, trace|
      original = ENV.fetch('TMPDIR', nil)
      ENV['TMPDIR'] = root
      assert_equal 'not_checked', check('`shaka merge` checks the head.', root:).fetch('status')
      refute_path_exists trace
    ensure
      ENV['TMPDIR'] = original
    end
  end

  def test_reuses_a_cached_pass_without_another_model_call
    with_claude(parse('Pull requests', true)) do |root, trace|
      assert_equal 'passed', check('Pull requests show the outcome.', root:).fetch('status')
      File.unlink(trace)
      assert_equal 'passed', check('Pull requests show the outcome.', root:).fetch('status')
      refute_path_exists trace
    end
  end

  def test_unreadable_cache_entry_retries_the_model
    with_claude(parse('Pull requests', true)) do |root, trace|
      assert_equal 'passed', check('Pull requests show the outcome.', root:).fetch('status')
      path = Dir.glob(File.join(root, 'cache', '*')).fetch(0)
      File.unlink(path)
      Dir.mkdir(path)
      File.unlink(trace)
      assert_equal 'passed', check('Pull requests show the outcome.', root:).fetch('status')
      assert_path_exists trace
    end
  end

  private

  def write_model(bin, name, body)
    path = File.join(bin, name)
    File.write(path, "#!#{RbConfig.ruby}\n#{body}\n")
    File.chmod(0o755, path)
  end
end
