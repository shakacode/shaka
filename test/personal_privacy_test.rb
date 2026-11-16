# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/configuration/personal_privacy'
require 'shaka/publication_settings'
require 'shaka/publication/wip_details'
require 'shaka/task_start'
require 'tmpdir'
require 'yaml'
require 'json'

# Points HOME at a fresh directory holding the given personal file for the block.
module PersonalHome
  private

  # File contents: nil writes none, a String is written as is, and a Hash becomes a version 1 file.
  def with_home(file)
    Dir.mktmpdir('shaka-home') do |home|
      path = File.join(home, '.agents/shaka/config.yml')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, file.is_a?(String) ? file : YAML.dump({ 'version' => 1 }.merge(file))) unless file.nil?
      original = Dir.home
      ENV['HOME'] = home
      yield path
    ensure
      ENV['HOME'] = original
    end
  end
end

# A user's own ~/.agents/shaka/config.yml can hide their checkout path on everything they
# publish, but never shows a path a repository hides.
class PersonalPrivacyTest < Minitest::Test
  include PersonalHome

  PATH = '/private/customer/project'
  THREAD_ID = '0199a213-81c0-7800-8aa1-bbab2a035a53'
  WIP = Shaka::WipDetails::FIELDS.keys.to_h { |key| [key, 'UNKNOWN'] }.merge(
    'owner' => 'UNKNOWN · Codex · t1', 'revision' => 'a' * 40, 'state' => 'paused',
    'next_action' => 'Resume the owning chat', 'workspace' => PATH, 'thread' => "codex://threads/#{THREAD_ID}"
  ).freeze

  def test_your_file_hides_a_checkout_path_the_repository_shows
    with_home('wip' => { 'include_checkout_path' => false }) do
      body = wip_body(settings(true))
      assert_includes body, '| Workspace | REDACTED (personal setting) |'
      refute_includes body, PATH
      assert_includes body, THREAD_ID
    end
  end

  def test_your_file_never_shows_what_the_repository_hides
    with_home('wip' => { 'include_checkout_path' => true }) do
      assert_includes wip_body(settings(false)), '| Workspace | REDACTED |'
      unread = Shaka::PublicationSettings.new(privacy: Shaka::Configuration::PersonalPrivacy.load)
      assert_includes wip_body(unread), 'settings not read'
      assert_includes wip_body(settings(true)), "| Workspace | #{PATH} |"
    end
  end

  def test_the_issue_start_comment_follows_your_file
    with_home('wip' => { 'include_checkout_path' => false }) do
      content = { 'identity' => { 'agent' => 'Codex' }, 'summary' => 'Started.', 'wip' => WIP }
      body = Shaka::TaskStart.compose(content, path_redaction: settings(true).path_redaction)
      refute_includes body, PATH
    end
  end

  def test_unread_settings_keep_their_recovery_step_when_your_file_hides_the_path
    with_home('wip' => { 'include_checkout_path' => false }) do
      unread = Shaka::PublicationSettings.new(privacy: Shaka::Configuration::PersonalPrivacy.load)
      assert_includes wip_body(unread), 'rerun description with --ref'
    end
  end

  def test_the_report_names_which_choice_hides_the_path
    with_home('wip' => { 'include_checkout_path' => false }) do |path|
      report = Shaka::Configuration::PersonalPrivacy.load.method(:report)
      assert_equal({ 'personal_file' => path, 'checkout_path' => 'hidden by your personal file' },
                   report.call(repository_shows_checkout_path: true))
      assert_equal 'hidden by the repository setting',
                   report.call(repository_shows_checkout_path: false)['checkout_path']
    end
  end

  private

  def settings(repository_shows, privacy = Shaka::Configuration::PersonalPrivacy.load)
    Shaka::PublicationSettings.new(current: { 'wip.include_checkout_path' => repository_shows }, privacy:)
  end

  def wip_body(settings)
    Shaka::WipDetails.new(WIP, path_redaction: settings.path_redaction).detail.fetch('body')
  end
end

# A missing file hides nothing; a file Shaka cannot read hides the path, so a broken choice cannot publish it.
class PersonalPrivacyFileTest < Minitest::Test
  include PersonalHome

  def test_no_file_hides_nothing
    with_home(nil) do
      privacy = Shaka::Configuration::PersonalPrivacy.load
      assert_predicate privacy, :checkout_path?
      assert_nil privacy.warning
    end
  end

  def test_a_folder_shaka_cannot_open_hides_the_path
    skip 'root opens every folder' if Process.uid.zero?
    with_home('wip' => { 'include_checkout_path' => true }) do |path|
      File.chmod(0o000, File.dirname(path))
      assert_hidden_with_warning(path)
    ensure
      File.chmod(0o755, File.dirname(path))
    end
  end

  def test_a_link_to_a_missing_file_hides_the_path
    with_home(nil) do |path|
      File.symlink(File.join(File.dirname(path), 'unmounted/config.yml'), path)
      assert_hidden_with_warning(path)
    end
  end

  def test_a_file_where_the_folder_belongs_hides_the_path
    with_home(nil) do |path|
      FileUtils.rm_rf(File.dirname(path))
      File.write(File.dirname(path), "version: 1\nwip:\n  include_checkout_path: true\n")
      assert_hidden_with_warning(path)
    end
  end

  def test_a_file_shaka_cannot_read_hides_the_path_and_says_why
    ["not: [valid\n", "wip: {}\n", { 'wip' => { 'include_checkout_path' => 'no' } },
     { 'wip' => ['include_checkout_path'] }].each do |file|
      with_home(file) { |path| assert_hidden_with_warning(path) }
    end
  end

  private

  def assert_hidden_with_warning(path)
    privacy = Shaka::Configuration::PersonalPrivacy.load
    refute_predicate privacy, :checkout_path?
    assert_includes privacy.warning, path
  end
end

# The real `start` command reads the personal file and says why a broken one hides the path.
class PersonalPrivacyStartCommandTest < Minitest::Test
  include RepositoryConfigTestHelpers

  FAKE_GH = <<~RUBY
    require 'json'
    raw = STDIN.read
    request = raw.strip.empty? ? {} : JSON.parse(raw)
    case ARGV[1]
    when 'repos/owner/repo/issues/42' then puts JSON.generate('number' => 42, 'title' => 'Task')
    when 'user' then puts JSON.generate('login' => 'author')
    when %r{\\Arepos/owner/repo/issues/42/comments}
      if ARGV.include?('POST')
        File.write(File.join(ENV.fetch('HOME'), 'published.md'), request.fetch('body'))
        puts JSON.generate(request.merge('id' => 9))
      else puts '[]'
      end
    when 'markdown' then puts JSON.generate('<table></table>' * 10)
    else abort "unexpected gh request: \#{ARGV.inspect}"
    end
  RUBY

  def test_a_broken_personal_file_hides_the_path_on_the_issue_comment
    with_repository('wip' => { 'include_checkout_path' => true }) do |root|
      ref = commit_settings(root)
      Dir.mktmpdir('shaka-home') do |home|
        error = start(home, root, ref)
        body = File.read(File.join(home, 'published.md'))
        assert_includes error, 'Hiding the checkout path on publications'
        assert_includes body, '| Workspace | REDACTED (personal setting) |'
        refute_includes body, PersonalPrivacyTest::PATH
      end
    end
  end

  private

  def start(home, root, ref)
    write_home(home)
    content = File.join(home, 'content.json')
    File.write(content, JSON.generate('identity' => { 'agent' => 'Codex' }, 'summary' => 'Started.',
                                      'wip' => PersonalPrivacyTest::WIP))
    env = SESSION_ENV_CLEARED.merge('HOME' => home, 'PATH' => "#{home}:#{ENV.fetch('PATH')}")
    _output, error, status = Open3.capture3(env, *SHAKA_COMMAND, 'start', 'owner/repo', '42', '--root', root,
                                            '--ref', ref, '--content-file', content)
    assert_predicate status, :success?, error
    error
  end

  # A broken personal file and a fake gh that keeps the comment it would post.
  def write_home(home)
    FileUtils.mkdir_p(File.join(home, '.agents/shaka'))
    File.write(File.join(home, '.agents/shaka/config.yml'), "not: [valid\n")
    gh = File.join(home, 'gh')
    File.write(gh, "#!#{RbConfig.ruby}\n#{FAKE_GH}")
    File.chmod(0o755, gh)
  end

  def commit_settings(root)
    [%w[init -q -b main], %w[add -A], %w[-c user.name=t -c user.email=t@example.com commit -qm settings]].each do |args|
      system(TEST_GIT, '-C', root, *args, exception: true)
    end
    Open3.capture2(TEST_GIT, '-C', root, 'rev-parse', 'HEAD').first.strip
  end
end
