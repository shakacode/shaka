# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require_relative '../skills/shaka/lib/shaka/opening_check'

class OpeningCheckTest < Minitest::Test
  COMMAND_FIRST = '`shaka merge` now stops before submitting a PR that has no local-review attestation ' \
                  'covering its head.'
  OUTCOME_FIRST = 'Pull requests for Linear and other tracker issues now link to their issue.'

  def test_flags_a_first_sentence_led_by_a_command
    with_claude(parse('shaka merge', false)) do |root, trace|
      result = check(COMMAND_FIRST, root:)
      assert_equal 'flagged', result.fetch('status')
      assert_includes result.fetch('reason'), '"shaka merge"'
      assert_equal 'shaka merge', result.dig('parse', 0, 'character')
      assert_invoked_outside(root, trace)
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

  private

  def assert_invoked_outside(root, trace)
    invocation = JSON.parse(File.read(trace))
    assert_includes invocation.fetch('prompt'), COMMAND_FIRST
    refute invocation.fetch('pwd').start_with?(File.realpath(root)), 'the model must not run inside the checkout'
  end

  def check(summary, root:, published: '')
    Shaka::OpeningCheck.new(summary:, body: render(summary), published_body: published,
                            candidate_root: File.realpath(root)).call
  end

  def render(summary) = "**Author:** agent\n\n#{summary}\n\n| Check |\n| --- |\n| ok |\n"

  def parse(character, reader_facing)
    { is_error: false, structured_output: { sentences: [{ character:, reader_facing:, action: 'acts',
                                                          object: 'something', hidden_actions: [],
                                                          internal_terms: [] }] } }
  end

  # The fake CLI lives in its own directory beside a separate candidate root.
  def with_claude(output, body: nil)
    Dir.mktmpdir do |dir|
      bin = File.join(dir, 'bin')
      root = File.join(dir, 'checkout')
      [bin, root].each { |path| Dir.mkdir(path) }
      trace = File.join(dir, 'trace.json')
      body ||= "puts #{JSON.generate(output).inspect}"
      write_claude(bin, trace, body)
      with_path(bin) { yield(root, trace, bin) }
    end
  end

  def write_claude(bin, trace, body)
    path = File.join(bin, 'claude')
    File.write(path, <<~RUBY)
      #!#{RbConfig.ruby}
      require 'json'
      File.write(#{trace.inspect}, JSON.generate({ args: ARGV, prompt: STDIN.read, pwd: Dir.pwd }))
      #{body}
    RUBY
    File.chmod(0o755, path)
  end

  def with_path(path)
    original = ENV.fetch('PATH', nil)
    ENV['PATH'] = path
    yield
  ensure
    ENV['PATH'] = original
  end
end
