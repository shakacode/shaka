# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/configuration/personal_privacy'
require 'shaka/publication_settings'
require 'shaka/publication/wip_details'
require 'shaka/handoff/wip_note'
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

# A user's own ~/.agents/shaka/config.yml can hide the checkout path and chat link on everything
# they publish, but never shows what a repository hides.
class PersonalPrivacyTest < Minitest::Test
  include PersonalHome

  PATH = '/private/customer/project'
  THREAD_ID = '0199a213-81c0-7800-8aa1-bbab2a035a53'
  LOCATOR = "codex://threads/#{THREAD_ID}".freeze
  WIP = Shaka::WipDetails::FIELDS.keys.to_h { |key| [key, 'UNKNOWN'] }.merge(
    'owner' => 'UNKNOWN · Codex · t1', 'revision' => 'a' * 40, 'state' => 'paused',
    'next_action' => 'Resume the owning chat', 'workspace' => PATH, 'thread' => LOCATOR
  ).freeze
  CODEX = { 'CODEX_THREAD_ID' => THREAD_ID }.freeze

  def test_your_file_hides_a_checkout_path_the_repository_shows
    with_home('wip' => { 'include_checkout_path' => false }) do
      body = wip_body(settings(true))
      assert_includes body, '| Workspace | REDACTED (personal setting) |'
      refute_includes body, PATH
    end
  end

  def test_your_file_never_shows_what_the_repository_hides
    with_home('wip' => { 'include_checkout_path' => true, 'include_chat_link' => true }) do
      assert_includes wip_body(settings(false)), '| Workspace | REDACTED |'
      unread = Shaka::PublicationSettings.new(privacy: Shaka::Configuration::PersonalPrivacy.load)
      assert_includes wip_body(unread), 'settings not read'
      assert_includes wip_body(settings(true)), "| Workspace | #{PATH} |"
    end
  end

  def test_your_file_withholds_the_chat_link_and_handoff_accepts_the_note
    with_home('wip' => { 'include_chat_link' => false }) do
      privacy = Shaka::Configuration::PersonalPrivacy.load
      content = privacy.apply({ 'wip' => WIP, 'wip_disclosure' => { 'alias' => 'withheld' } })
      assert_equal({ 'alias' => 'withheld', 'thread' => 'withheld' }, content['wip_disclosure'])

      body = wip_body(settings(true), content)
      assert_includes body, '| Chat link | UNKNOWN |'
      refute_includes body, THREAD_ID
      assert_includes body, 'thread withheld'
      assert_nil Shaka::WipMetadata.handoff_problem(body, owner: WIP['owner'], thread: 'UNKNOWN')
    end
  end

  def test_the_issue_start_comment_follows_your_file
    with_home('wip' => { 'include_checkout_path' => false, 'include_chat_link' => false }) do
      privacy = Shaka::Configuration::PersonalPrivacy.load
      redaction = settings(true, privacy).path_redaction
      content = { 'identity' => { 'agent' => 'Codex' }, 'summary' => 'Started.', 'wip' => WIP }
      body = Shaka::TaskStart.compose(content, path_redaction: redaction, privacy:)
      refute_includes body, PATH
      refute_includes body, THREAD_ID
    end
  end

  def test_unread_settings_keep_their_recovery_step_when_your_file_hides_the_path
    with_home('wip' => { 'include_checkout_path' => false }) do
      unread = Shaka::PublicationSettings.new(privacy: Shaka::Configuration::PersonalPrivacy.load)
      assert_includes wip_body(unread), 'rerun description with --ref'
    end
  end

  def test_the_report_names_which_choice_hides_each_value
    with_home('wip' => { 'include_checkout_path' => false, 'include_chat_link' => false }) do |path|
      report = Shaka::Configuration::PersonalPrivacy.load.method(:report)
      hidden = 'hidden by your personal file'
      assert_equal({ 'personal_file' => path, 'checkout_path' => hidden, 'chat_link' => hidden },
                   report.call(repository_shows_checkout_path: true))
      assert_equal 'hidden by the repository setting',
                   report.call(repository_shows_checkout_path: false)['checkout_path']
    end
  end

  private

  def settings(repository_shows, privacy = Shaka::Configuration::PersonalPrivacy.load)
    Shaka::PublicationSettings.new(current: { 'wip.include_checkout_path' => repository_shows }, privacy:)
  end

  def wip_body(settings, content = { 'wip' => WIP })
    session = { environment: CODEX, disclosure: content['wip_disclosure'] }
    Shaka::WipDetails.new(content['wip'], path_redaction: settings.path_redaction, session:).detail.fetch('body')
  end
end

# A missing file hides nothing; a file Shaka cannot read hides both, so a broken choice cannot publish.
class PersonalPrivacyFileTest < Minitest::Test
  include PersonalHome

  def test_no_file_hides_nothing
    with_home(nil) do
      privacy = Shaka::Configuration::PersonalPrivacy.load
      assert privacy.checkout_path? && privacy.chat_link? && privacy.warning.nil?
      assert_same PersonalPrivacyTest::WIP, privacy.apply(PersonalPrivacyTest::WIP)
    end
  end

  def test_a_folder_shaka_cannot_open_hides_both
    skip 'root opens every folder' if Process.uid.zero?
    with_home('wip' => { 'include_checkout_path' => true }) do |path|
      File.chmod(0o000, File.dirname(path))
      privacy = Shaka::Configuration::PersonalPrivacy.load
      refute privacy.checkout_path? || privacy.chat_link?
      assert_includes privacy.warning, path
    ensure
      File.chmod(0o755, File.dirname(path))
    end
  end

  def test_a_file_shaka_cannot_read_hides_both_and_says_why
    ["not: [valid\n", "wip: {}\n", { 'wip' => { 'include_chat_link' => 'no' } },
     { 'wip' => ['include_checkout_path'] }].each do |file|
      with_home(file) do |path|
        privacy = Shaka::Configuration::PersonalPrivacy.load
        refute privacy.checkout_path? || privacy.chat_link?, file.inspect
        assert_includes privacy.warning, path
      end
    end
  end
end

# No repository setting holds the chat link choice, so setup leaves it in the personal file.
class PersonalChatLinkSetupTest < Minitest::Test
  def test_setup_keeps_the_chat_link_choice_out_of_the_new_clone
    values = { 'wip' => { 'include_checkout_path' => false, 'include_chat_link' => false } }
    personal = Shaka::Configuration::PersonalSettings.new('config.yml', values)
    assert_equal({ 'wip' => { 'include_checkout_path' => false } }, personal.values)
    assert_equal ['wip.include_checkout_path'], personal.keys

    error = assert_raises(Shaka::Error) do
      Shaka::Configuration::PersonalSettings.new('config.yml', { 'wip' => { 'include_chat_link' => 'no' } })
    end
    assert_includes error.message, 'wip.include_chat_link must be true or false'
  end
end

# The real `start` command reads the personal file and says why a broken one hides everything.
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

  def test_a_broken_personal_file_hides_both_on_the_issue_comment
    with_repository('wip' => { 'include_checkout_path' => true }) do |root|
      ref = commit_settings(root)
      Dir.mktmpdir('shaka-home') do |home|
        error = start(home, root, ref)
        body = File.read(File.join(home, 'published.md'))
        assert_includes error, 'Hiding the checkout path and chat link'
        assert_includes body, '| Workspace | REDACTED (personal setting) |'
        [PersonalPrivacyTest::PATH, PersonalPrivacyTest::THREAD_ID].each { |value| refute_includes body, value }
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
