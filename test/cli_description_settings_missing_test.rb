# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require 'json'
require 'shaka/publication/links'

# The description command, run as an agent runs it in a repository that never set Shaka up, leads with that fact.
class CliDescriptionSettingsMissingTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = SHAKA_COMMAND
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'A counter resets to zero.'

  # The writer identity stays the first line; the statement comes right after it, above the summary.
  def test_a_description_from_a_checkout_without_settings_says_they_were_missing
    body = published(remove_settings: true)
    blocks = body.split("\n\n").map(&:strip).reject { it.empty? || it.start_with?('<!--') }
    assert_equal Shaka::PublicationLinks::SETTINGS_MISSING, blocks[1]
    assert_operator body.index(Shaka::PublicationLinks::SETTINGS_MISSING), :<, body.index('## Summary')
  end

  def test_a_description_from_a_checkout_with_settings_does_not
    refute_includes published(remove_settings: false), Shaka::PublicationLinks::SETTINGS_MISSING
  end

  private

  def published(remove_settings:)
    with_repository do |root|
      FileUtils.rm_rf(File.join(root, '.agents')) if remove_settings
      File.write(File.join(root, 'README.md'), "A counter\n")
      commit(root)
      Dir.mktmpdir { |dir| return describe(root, dir) }
    end
  end

  # No --ref, as the no-settings path in the repository setup guide runs it.
  def describe(root, dir)
    write_fake_commands(dir)
    content = File.join(dir, 'content.json')
    File.write(content, JSON.generate(description_content))
    _output, error, status = Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir },
                                            *COMMAND, 'description', 'owner/repo', '1',
                                            '--root', root, '--content-file', content)
    assert_predicate status, :success?, error
    File.read(File.join(dir, 'published.md'))
  end
end
