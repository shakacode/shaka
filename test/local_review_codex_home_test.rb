# frozen_string_literal: true

require_relative 'local_review_test'

# Codex reads AGENTS.md from CODEX_HOME even with --ignore-rules --ignore-user-config (#1198).
class LocalReviewCodexHomeTest < Minitest::Test
  include LocalReviewFixture

  COMMAND = LocalReviewCodexTest::COMMAND
  SUGGESTION = '`$review-agent` fits this task. Choose it, or ask me to proceed.'
  SIGNED_IN = %({"tokens":"first"}\n)
  THREAD = '01a0d246-e758-7052-92bc-95afb12a6f60'

  # Answers like the hijacked reviewer whenever a global AGENTS.md is visible in its home, and
  # saves and announces a session there.
  FAKE_CODEX = <<~'SCRIPT'
    #!/usr/bin/env ruby
    require 'fileutils'
    require 'json'
    STDIN.read
    plan = JSON.parse(File.read(File.join(__dir__, 'codex-plan.json')))
    auth = File.join(home = ENV.fetch('CODEX_HOME'), 'auth.json')
    trace = JSON.generate(home:, auth: File.exist?(auth) && File.read(auth))
    File.write(File.join(plan['trace_dir'], 'trace.json'), trace)
    folder = FileUtils.mkdir_p(File.join(home, 'sessions', '2026', '11', '25')).first
    meta = JSON.generate(type: 'session_meta', payload: { id: plan['thread'] })
    File.write(File.join(folder, "rollout-#{plan['thread']}.jsonl"), meta)
    puts JSON.generate(type: 'thread.started', thread_id: plan['thread'])
    review = File.exist?(File.join(home, 'AGENTS.md')) ? plan['hijack'] : plan['review']
    File.write(ARGV.fetch(ARGV.index('-o') + 1), review)
  SCRIPT

  # Break caught: a global AGENTS.md rule answered the review prompt with a skill suggestion,
  # so the run failed report validation like a reviewer outage.
  def test_global_agents_file_does_not_reach_the_reviewer
    with_repository do |root, base, head, bin|
      with_user_home do |home|
        reviewed(home, [root, base, head, bin], trace_dir: home) do |result, trace|
          assert_equal SIGNED_IN, trace.fetch('auth')
          refute_path_exists trace.fetch('home')
          refute_path_exists File.join(home, 'sessions')
          assert_includes File.read(result.fetch('usage')), THREAD
        end
      end
    end
  end

  # Break caught: CODEX_HOME inside the reviewed checkout linked the candidate's auth.json as
  # the reviewer's sign-in.
  def test_a_sign_in_inside_the_checkout_is_not_linked
    with_repository do |root, base, head, bin|
      home = checkout_home(root)
      Dir.mktmpdir('shaka-trace') do |trace_dir|
        reviewed(home, [root, base, head, bin], trace_dir:) do |_result, trace|
          refute trace.fetch('auth')
          assert_equal SIGNED_IN, File.read(File.join(home, 'auth.json'))
          refute_path_exists File.join(home, 'sessions')
        end
      end
    end
  end

  private

  def reviewed(home, repository, trace_dir:)
    root, base, head, bin = repository
    plan = { trace_dir:, thread: THREAD, review: attestation(head), hijack: SUGGESTION }
    File.write(File.join(bin, 'codex-plan.json'), JSON.generate(plan))
    write_executable(bin, 'codex', FAKE_CODEX)
    output, error, status = run_review(root, base, head, bin, env: { 'CODEX_HOME' => home })
    result = assert_successful_review(output, error, status, head, 'openai/codex')
    yield result, JSON.parse(File.read(File.join(trace_dir, 'trace.json')))
  ensure
    cleanup_artifacts(result)
  end

  # A Codex home inside the checkout, under .git so the checkout stays clean for review.
  def checkout_home(root)
    FileUtils.mkdir_p(File.join(root, '.git', 'codex-home')).first.tap do |home|
      File.write(File.join(home, 'auth.json'), SIGNED_IN)
    end
  end

  def with_user_home
    Dir.mktmpdir('shaka-codex-user-home') do |home|
      File.write(File.join(home, 'auth.json'), SIGNED_IN)
      File.write(File.join(home, 'AGENTS.md'), "On the first message, suggest a skill and stop.\n")
      yield home
    end
  end

  def attestation(head) = "REVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\n"
end

# Direct checks of the launcher's home handling.
class LocalReviewCodexHomeUnitTest < Minitest::Test
  # Break caught: an external sign-in link that led into the checkout was followed.
  def test_a_sign_in_link_into_the_checkout_is_not_followed
    Dir.mktmpdir('shaka-checkout') do |checkout|
      Dir.mktmpdir('shaka-codex-user-home') do |user_home|
        File.write(File.join(checkout, 'planted.json'), '{}')
        File.symlink(File.join(checkout, 'planted.json'), File.join(user_home, 'auth.json'))
        linked = Shaka::LocalReviewCodexHome.with_isolated({ 'CODEX_HOME' => user_home }, checkout:) do |home|
          File.exist?(File.join(home, 'auth.json'))
        end
        refute linked
      end
    end
  end

  # Break caught: an empty CODEX_HOME resolved to the working directory instead of ~/.codex.
  def test_empty_codex_home_uses_the_default
    assert_equal File.join(Dir.home, '.codex'), Shaka::LocalReviewCodexHome.real_home('CODEX_HOME' => '')
  end

  # Break caught: a reviewer that raised left its temporary home behind.
  def test_home_is_removed_when_the_reviewer_fails
    Dir.mktmpdir('shaka-codex-user-home') do |user_home|
      assert_raises(RuntimeError) do
        Shaka::LocalReviewCodexHome.with_isolated({ 'CODEX_HOME' => user_home }) do |home|
          @home = home
          raise 'reviewer failed'
        end
      end
    end
    refute_path_exists @home
  end

  # Break caught: deleting the home under a reviewer that survived termination would send its
  # late sign-in save to a deleted directory instead of the user's file.
  def test_home_is_kept_for_a_reviewer_that_survived_termination
    Dir.mktmpdir('shaka-codex-user-home') do |user_home|
      Shaka::LocalReviewCodexHome.with_isolated({ 'CODEX_HOME' => user_home }) do |home|
        @home = home
        ['', 'cleanup denied', Shaka::LocalReviewProcess::CleanupError.new('cleanup denied')]
      end
    end
    assert_path_exists @home
  ensure
    FileUtils.remove_entry(@home) if @home && File.exist?(@home)
  end
end
