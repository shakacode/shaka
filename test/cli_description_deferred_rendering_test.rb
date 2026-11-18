# frozen_string_literal: true

# Proves the description command opts in to checking the stored rendering where GitHub refuses its renderer.

require_relative 'test_helper'
require_relative 'cli_opening_check_fakes'
require 'json'
require 'shaka/github'

class CliDescriptionDeferredRenderingTest < Minitest::Test
  include CliOpeningCheckFakes

  COMMAND = SHAKA_COMMAND
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Publish the description where the renderer is refused.'

  def test_a_refused_renderer_and_graphql_still_publish_the_description
    Dir.mktmpdir do |dir|
      output, error, status = run_description(dir)

      assert_predicate status, :success?, error
      assert_match(/\A#{Regexp.escape(Shaka::DescriptionPublishing::CHECKED_AFTER)}/o,
                   JSON.parse(output).fetch('rendering'))
      assert_includes File.read(File.join(dir, 'patch-args.json')), 'Accept: application/vnd.github.full+json'
    end
  end

  private

  # Answers as a Claude Code cloud session does: GraphQL and `POST /markdown` are refused with HTTP 403.
  def fake_gh
    super.sub("when 'markdown' then puts JSON.generate('<table></table>' * 10)",
              "when 'markdown' then abort 'gh: This GitHub API path is not available (HTTP 403)'")
         .sub(/^when 'graphql'\n.*?\nelse/m,
              "when 'graphql' then abort 'gh: GitHub GraphQL is not available (HTTP 403)'\nelse")
         .sub('    puts JSON.generate(request)', <<~'RUBY')
           File.write(File.join(ENV.fetch('HOME'), 'patch-args.json'), JSON.generate(ARGV))
           puts JSON.generate(request.merge('body_html' => "<p>Done.</p>#{'<table></table>' * 10}"))
         RUBY
  end
end
