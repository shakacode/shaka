# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require_relative '../skills/shaka/lib/shaka/opening_check'
require_relative 'opening_check_test_helpers'

class OpeningCheckTest < Minitest::Test
  include OpeningCheckTestHelpers

  COMMAND_FIRST = '`shaka merge` now stops before submitting a PR that has no local-review attestation ' \
                  'covering its head.'
  OUTCOME_FIRST = 'Pull requests for Linear and other tracker issues now link to their issue.'

  def test_flags_a_first_sentence_led_by_a_command
    with_claude(parse('shaka merge', false)) do |root, trace|
      result = check(COMMAND_FIRST, root:)
      assert_equal 'flagged', result.fetch('status')
      assert_includes result.fetch('reason'), '"shaka merge"'
      assert_equal 'shaka merge', result.dig('parse', 0, 'character')
      assert_invoked_outside(root, trace, COMMAND_FIRST)
    end
  end

  def test_passes_a_first_sentence_led_by_what_the_reader_sees
    with_claude(parse('Pull requests', true)) do |root, _trace|
      assert_equal 'passed', check(OUTCOME_FIRST, root:).fetch('status')
    end
  end

  def test_sends_only_the_opening_paragraph
    with_claude(parse('Pull requests', true)) do |root, trace|
      check("#{OUTCOME_FIRST}\n\nA later paragraph about `shaka claim`.", root:)
      refute_includes JSON.parse(File.read(trace)).fetch('prompt'), 'later paragraph'
    end
  end

  def test_skips_the_model_when_the_published_opening_is_unchanged
    with_claude(parse('shaka merge', false)) do |root, trace|
      result = check(COMMAND_FIRST, root:, published: "<!-- shaka:begin -->\n#{render(COMMAND_FIRST)}")
      assert_equal({ 'status' => 'unchanged' }, result)
      refute_path_exists trace
    end
  end

  def test_checks_a_shortened_opening
    with_claude(parse('shaka merge', false)) do |root, _trace|
      published = render("#{COMMAND_FIRST} It also reports the reason.")
      assert_equal 'flagged', check(COMMAND_FIRST, root:, published:).fetch('status')
    end
  end

  def test_checkout_root_covers_the_whole_repository_from_a_subdirectory
    Dir.mktmpdir do |dir|
      system('git', 'init', '-q', dir, exception: true)
      Dir.mkdir(File.join(dir, 'docs'))
      assert_equal File.realpath(dir), Shaka::OpeningCheck.checkout_root(File.join(dir, 'docs'))
    end
  end

  def test_checks_a_later_paragraph_promoted_to_the_opening
    with_claude(parse('shaka merge', false)) do |root, _trace|
      published = render("#{OUTCOME_FIRST}\n\n#{COMMAND_FIRST}")
      assert_equal 'flagged', check(COMMAND_FIRST, root:, published:).fetch('status')
    end
  end

  def test_missing_cli_is_not_checked
    Dir.mktmpdir do |root|
      with_path(File.join(root, 'empty-bin')) do
        assert_equal({ 'status' => 'not_checked', 'reason' => 'claude is not on PATH' },
                     check(COMMAND_FIRST, root:))
      end
    end
  end

  def test_failed_or_malformed_runs_are_not_checked
    ['exit 3', 'puts "not json"', 'puts JSON.generate(is_error: true)',
     'puts JSON.generate(structured_output: { sentences: [{ character: "x" }] })'].each do |body|
      with_claude(nil, body:) do |root, _trace|
        assert_equal 'not_checked', check(COMMAND_FIRST, root:).fetch('status'), body
      end
    end
  end

  def test_a_cli_inside_the_checkout_is_not_run
    with_claude(parse('shaka merge', false)) do |_root, trace, bin|
      assert_equal 'not_checked', check(COMMAND_FIRST, root: bin).fetch('status')
      refute_path_exists trace
    end
  end
end
