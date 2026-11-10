# frozen_string_literal: true

# Proves the description command reads the risk level from this head's checkpoint, the trusted settings, and the
# changed files, as merge reads them, through the real command.

require_relative 'test_helper'
require_relative 'cli_opening_check_fakes'
require 'json'
require 'shaka/post_implementation/evidence'

class CliDescriptionRiskTest < Minitest::Test
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Adds an index.'
  HEAD = 'c' * 40
  EVIDENCE = Shaka::PostImplementationEvidence

  def description_content = super.merge('checkpoint' => { 'head' => HEAD })

  # The reviewer rated the change low. Its file sits in this repository's own merge_and_trust area, which the
  # packaged areas lack.
  CHANGED = 'skills/shaka/lib/shaka/seam.rb'

  def checkpoint_body
    assessment = Shaka::PostImplementationRisk.assess('low', {}, [CHANGED])
    section = Shaka::PostImplementationRisk.section(assessment, ['Prints text only.'])
    "<!-- shaka:reply:post-implementation-ccccccc-abc12345 -->\n# Checkpoint\n\n#{section}\n\n" \
      "#{EVIDENCE.risk('low')}\n#{EVIDENCE.adequacy('adequate')}\n#{EVIDENCE.disposition('Merge')}\n" \
      "#{EVIDENCE.attestation(HEAD, 'ready')}"
  end

  def comments
    return @comments if @comments

    [{ 'id' => 1, 'created_at' => '2026-11-09T00:00:00Z', 'user' => { 'login' => 'agent' },
       'html_url' => 'https://github.com/owner/repo/pull/1#issuecomment-7', 'body' => checkpoint_body }]
  end

  def fake_gh
    <<~RUBY
      require 'json'
      raw = STDIN.read
      request = raw.strip.empty? ? {} : JSON.parse(raw)
      case ARGV[1]
      when 'user' then puts JSON.generate('login' => 'agent')
      when 'repos/owner/repo/pulls/1'
        if ARGV.include?('PATCH')
          File.write(File.join(ENV.fetch('HOME'), 'published.md'), request.fetch('body'))
          puts JSON.generate(request)
        else
          puts JSON.generate('body' => '', 'head' => { 'sha' => '#{HEAD}' }, 'base' => { 'sha' => '#{'b' * 40}' },
                             'changed_files' => 1, 'additions' => 5, 'deletions' => 0)
        end
      when %r{pulls/1/files} then puts JSON.generate([{ 'filename' => '#{CHANGED}', 'status' => 'modified' }])
      when %r{issues/1/comments} then puts #{JSON.generate(comments).inspect}
      when 'markdown' then puts JSON.generate('<table></table>' * 10)
      when 'graphql'
        references = { 'totalCount' => 0, 'nodes' => [] }
        puts JSON.generate('data' => { 'repository' => { 'pullRequest' => { 'closingIssuesReferences' => references } } })
      else abort "unexpected gh request: \#{ARGV.inspect}"
      end
    RUBY
  end

  def test_the_level_applies_the_repositorys_own_areas_from_trusted_settings
    Dir.mktmpdir do |dir|
      _output, error, status = run_description(dir, ref: true)

      assert_predicate status, :success?, error
      body = File.read(File.join(dir, 'published.md'))
      assert_includes body, '**Recommendation: Merge** · **Risk: High** · '
      assert_includes body, "## Risk and review\n\n**High**, raised from the reviewer's low by `merge_and_trust` " \
                            "(`#{CHANGED}`). High risk is meant for a person to merge"
      assert_includes body, '**The [checkpoint](https://github.com/owner/repo/pull/1#issuecomment-7) reviewer ' \
                            "rated it low:**\n\n- Prints text only."
    end
  end

  def test_before_the_checkpoint_publishes_the_level_reads_not_rated_yet
    @comments = []
    Dir.mktmpdir do |dir|
      _output, error, status = run_description(dir, ref: true)

      assert_predicate status, :success?, error
      body = File.read(File.join(dir, 'published.md'))
      assert_includes body, '**No recommendation yet** · **Risk: not rated yet** · '
    end
  end

  def test_an_unrated_head_without_trusted_settings_still_reads_not_rated_yet
    @comments = []
    Dir.mktmpdir do |dir|
      _output, error, status = run_description(dir)

      assert_predicate status, :success?, error
      assert_includes File.read(File.join(dir, 'published.md')), '**Risk: not rated yet**'
    end
  end

  # The packaged areas would rate this low, so without the repository's settings the level is withheld.
  def test_without_trusted_settings_the_level_is_not_shown
    Dir.mktmpdir do |dir|
      _output, error, status = run_description(dir)

      assert_predicate status, :success?, error
      body = File.read(File.join(dir, 'published.md'))
      assert_includes body, '**Recommendation: Merge** · **Risk: not shown** · '
      refute_includes body, 'Risk: Low'
    end
  end
end
