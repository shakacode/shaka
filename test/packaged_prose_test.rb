# frozen_string_literal: true

require_relative 'test_helper'
require 'ripper'

# Heredoc prose of 25 or more words belongs in a packaged skills/shaka/config/*.md file, loaded
# with Shaka::PackagedText, so reviewers and maintainers read and edit it as text. One-line
# messages, even long ones joined with `\`, stay in Ruby: they are refusals and status lines.
class PackagedProseTest < Minitest::Test
  LIB = File.expand_path('../skills/shaka/lib', __dir__)
  WORD_LIMIT = 25
  GRAPHQL = /\A\s*(query|mutation)\b/
  WORDS = (['word'] * 13).join(' ')
  # Heredocs allowed to stay in Ruby, keyed by path and their first words, with the reason.
  ALLOWED = {
    ['shaka/issue_create.rb', 'Usage: shaka issue-create'] =>
      '--help text for one command, printed by that command and read beside its options',
    ['shaka/usage/command.rb', 'Native usage is PARTIAL.'] =>
      'report layout: its words are field labels between computed values, not prose to edit',
    ['shaka/welcome.rb', 'Give your coding agent'] =>
      'first-run help the CLI prints to a person before any repository or prompt exists'
  }.freeze

  # Each heredoc's opening line and its literal text; interpolated code is left out.
  class Heredocs
    def self.scan(source) = new.scan(source)

    def initialize
      @found = []
      @open = []
      @embedded = 0
    end

    def scan(source)
      Ripper.lex(source).each { |(line, _column), event, token| take(line, event, token) }
      @found
    end

    private

    def take(line, event, token)
      case event
      when :on_heredoc_beg then @open.push([line, +''])
      when :on_heredoc_end then @found << @open.pop
      when :on_embexpr_beg, :on_embexpr_end then @embedded += event == :on_embexpr_beg ? 1 : -1
      when :on_tstring_content then append(line, token)
      end
    end

    def append(line, token)
      @open.last[1] << token if @open.any? && @embedded.zero? && line > @open.last[0]
    end
  end

  def test_no_heredoc_prose_kept_in_ruby
    hits = Dir.glob('**/*.rb', base: LIB).sort.flat_map { |path| long_heredocs(path) }

    assert_empty hits, 'Move heredoc prose of 25+ words to skills/shaka/config/*.md and render it with ' \
                       "Shaka::PackagedText, or allowlist it in #{File.basename(__FILE__)} with a reason:\n" \
                       "#{hits.join("\n")}"
  end

  def test_scan_counts_heredoc_text_and_skips_graphql_and_one_line_strings
    source = <<~RUBY
      a = <<~A
        #{WORDS} \#{value}
        #{WORDS}
      A
      b = <<~Q
        query { #{WORDS} #{WORDS} }
      Q
      c = '#{WORDS} ' \\
          '#{WORDS}'
    RUBY

    assert_equal([[1, 26]], prose(source).map { |line, text| [line, text.split.size] })
  end

  def test_every_allowlist_entry_still_matches_a_long_heredoc
    ALLOWED.each_key do |path, opening|
      found = prose(read(path)).any? { |_line, text| text.lstrip.start_with?(opening) }

      assert found, "#{path} has no long heredoc starting #{opening.inspect}; remove its allowlist entry"
    end
  end

  def test_every_allowlist_entry_gives_a_reason
    ALLOWED.each { |key, reason| refute_empty reason.to_s.strip, "#{key.inspect} needs a reason" }
  end

  private

  def long_heredocs(path)
    prose(read(path)).filter_map do |line, text|
      next if ALLOWED.any? { |(allowed, opening), _| allowed == path && text.lstrip.start_with?(opening) }

      "skills/shaka/lib/#{path}:#{line} (#{text.split.size} words)"
    end
  end

  def prose(source)
    Heredocs.scan(source).select { |_line, text| text.split.size >= WORD_LIMIT && !GRAPHQL.match?(text) }
  end

  def read(path) = File.read(File.join(LIB, path), encoding: 'UTF-8')
end
