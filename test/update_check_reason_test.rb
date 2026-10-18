# frozen_string_literal: true

require_relative 'update_check_support'
require 'open3'

class UpdateCheckReasonTest < Minitest::Test
  include UpdateCheckSupport

  def test_signed_out_cli_names_the_sign_in_command
    error = "To get started with GitHub CLI, please run:  gh auth login\n"
    result = check('ahead', github: ['', error, false])
    assert_equal %w[unknown signed_out], [result.fetch('status'), result.fetch('reason')]
    assert_includes result.fetch('guidance'), 'Run `gh auth login`'
  end

  def test_failed_request_names_its_first_error_line
    offline = "\nerror connecting to api.github.com\ncheck your internet connection\n"
    result = check('ahead', github: ['', offline, false])
    assert_equal 'request_failed', result.fetch('reason')
    assert_includes result.fetch('guidance'), 'The GitHub request failed: error connecting to api.github.com'
    assert_includes result.fetch('guidance'), 'retry'
  end

  def test_malformed_network_answers_are_unknown
    [['not json', '', true], ['{}', '', true], ['[]', '', true]].each do |answer|
      result = check('ahead', github: answer)
      assert_equal %w[unknown invalid_response], [result.fetch('status'), result.fetch('reason')]
    end
  end

  def test_unreadable_checkout_is_unknown_with_its_reason
    runner = ->(argv, _directory) { argv.first == 'git' ? ['', "fatal: not a git repository\n", false] : flunk }
    result = Shaka::UpdateCheck.new(source: SOURCE, branch: 'main', checkout: CHECKOUT, helper: '/installed/shaka',
                                    runner:).result
    assert_equal 'checkout_unreadable', result.fetch('reason')
    assert_includes result.fetch('guidance'), 'fatal: not a git repository'
  end

  def test_missing_cli_is_advisory_and_names_the_command
    runner = ->(*) { raise Shaka::UpdateCheck::Launch::Unavailable.new('gh_missing', '`gh` was not found on PATH.') }
    result = Shaka::UpdateCheck.new(source: SOURCE, branch: 'main', helper: '/installed/shaka', runner:).result
    assert_equal %w[unknown gh_missing], [result.fetch('status'), result.fetch('reason')]
    assert_includes result.fetch('guidance'), '`gh` was not found on PATH.'
  end

  def test_manual_pull_of_a_real_checkout_reads_head_from_disk
    Dir.mktmpdir('shaka-update-pull') do |checkout|
      recorded = commit(checkout, 'first')
      pulled = commit(checkout, 'second')
      result = Shaka::UpdateCheck.new(source: SOURCE.merge('revision' => recorded), branch: 'main', checkout:,
                                      helper: '/installed/shaka', runner: method(:real_git)).result
      assert_equal 'drift', result.fetch('status')
      assert_includes result.fetch('guidance'), "checkout #{pulled[0, 7]}"
    end
  end

  private

  def real_git(argv, directory)
    argv.first == 'git' ? Shaka::UpdateCheck::Launch.capture(argv, directory) : ['{"status":"identical"}', '', true]
  end

  def commit(directory, message)
    git = ['git', '-C', directory, '-c', 'user.name=Test', '-c', 'user.email=test@example.com']
    system(*git, 'init', '--quiet', exception: true) unless File.directory?(File.join(directory, '.git'))
    system(*git, 'commit', '--quiet', '--allow-empty', '-m', message, exception: true)
    Open3.capture2(*git, 'rev-parse', 'HEAD').first.strip
  end
end
