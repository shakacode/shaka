# frozen_string_literal: true

require_relative 'publisher_attribution_test'
require_relative 'cli_opening_check_fakes'

class CliPublisherAttributionTest < Minitest::Test
  include PublisherAttributionFixture
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Missing attribution comes from the publisher session.'

  def test_description_publishes_native_header_and_provenance
    with_session(context) do |environment, _file|
      run_publication(environment) do |dir, output, error, status|
        assert_predicate status, :success?, "#{output}\n#{error}"
        body = File.read(File.join(dir, 'published.md'))
        assert_includes body, 'Codex · OpenAI · gpt-6.1-sol (configured) · medium'
        assert_includes body, '| Active model / effort | gpt-6.1-sol / medium |'
      end
    end
  end

  def test_conflicting_identity_does_not_write_to_github
    with_session(context) do |environment, _file|
      @conflict = true
      run_publication(environment) do |dir, _output, error, status|
        refute_predicate status, :success?
        assert_includes error, 'conflicts with native publisher settings'
        refute_path_exists File.join(dir, 'published.md')
      end
    end
  end

  private

  def description_content
    super.tap { |supplied| supplied['identity']['model'] = 'other-model' if @conflict }
  end

  def run_publication(environment)
    Dir.mktmpdir do |dir|
      write_fake_commands(dir)
      file = File.join(dir, 'content.json')
      File.write(file, JSON.generate(description_content))
      env = command_environment(environment, dir)
      result = Open3.capture3(env, COMMAND, 'description', 'owner/repo', '1', '--root', ROOT,
                              '--content-file', file)
      yield dir, *result
    end
  end

  def command_environment(environment, dir)
    environment.merge('PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir,
                      'CLAUDE_CODE_SESSION_ID' => nil, 'CURSOR_CONVERSATION_ID' => nil,
                      'OPENCODE_SESSION_ID' => nil, 'PI_CODING_AGENT' => nil)
  end
end
