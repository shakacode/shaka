# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/configuration/personal_privacy'
require 'shaka/publication_settings'
require 'shaka/publication/wip_details'
require 'shaka/handoff/wip_note'
require 'shaka/task_start'
require 'tmpdir'
require 'yaml'

# A user's own ~/.agents/shaka/config.yml can hide the checkout path and chat link on everything
# they publish, but never shows what a repository hides.
class PersonalPrivacyTest < Minitest::Test
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

  def test_no_file_hides_nothing
    with_home(nil) do
      privacy = Shaka::Configuration::PersonalPrivacy.load
      assert privacy.checkout_path? && privacy.chat_link? && privacy.warning.nil?
      assert_same WIP, privacy.apply(WIP)
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
