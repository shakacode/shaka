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

  def with_user_home
    Dir.mktmpdir('shaka-codex-user-home') do |home|
      File.write(File.join(home, 'auth.json'), SIGNED_IN)
      File.write(File.join(home, 'AGENTS.md'), "On the first message, suggest a skill and stop.\n")
      yield home
    end
  end

  def attestation(head) = "REVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\n"
end

# Saves a session for the test thread under a Codex home.
module CodexSessionFixture
  private

  # Saves a session for the test thread under the home and returns the events that announce it.
  def saved_session(home)
    thread = '01a0d246-e758-7052-92bc-95afb12a6f60'
    folder = FileUtils.mkdir_p(File.join(home, 'sessions', '2026', '11', '25')).first
    meta = JSON.generate(type: 'session_meta', payload: { id: thread })
    File.write(File.join(folder, "rollout-#{thread}.jsonl"), meta)
    JSON.generate(type: 'thread.started', thread_id: thread)
  end
end

# Direct checks of the launcher's home handling.
class LocalReviewCodexHomeUnitTest < Minitest::Test
  include CodexSessionFixture

  # Break caught: a failed session copy escaped after a successful review and discarded its report.
  def test_a_failed_session_copy_leaves_usage_unknown
    Dir.mktmpdir('shaka-codex-home') do |home|
      events = saved_session(home)
      before = Dir.glob(File.join(Dir.tmpdir, 'shaka-codex-session-*'))
      kept = with_failing_copy { Shaka::LocalReviewCodexHome.keep_session(events, home) }
      assert_nil kept
      assert_equal before, Dir.glob(File.join(Dir.tmpdir, 'shaka-codex-session-*'))
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

  private

  def with_failing_copy
    original = IO.method(:copy_stream)
    IO.define_singleton_method(:copy_stream) { |*| raise Errno::ENOSPC }
    yield
  ensure
    IO.define_singleton_method(:copy_stream, original)
  end
end

# The session copy that review usage reads after the temporary home is removed.
class LocalReviewCodexSessionCopyTest < Minitest::Test
  include CodexSessionFixture

  # Break caught: removing a failed session copy raised in turn and discarded the finished review.
  def test_a_failed_cleanup_after_a_failed_copy_leaves_usage_unknown
    Dir.mktmpdir('shaka-codex-home') do |home|
      events = saved_session(home)
      failing(IO, :copy_stream, Errno::ENOSPC) do
        failing(FileUtils, :rm_f, Errno::EACCES) do
          assert_nil Shaka::LocalReviewCodexHome.keep_session(events, home)
        end
      end
    end
  end

  # Break caught: brackets in the temporary home's path were read as a glob pattern, so the saved
  # session was missed and review usage read UNKNOWN.
  def test_the_session_is_found_under_a_path_with_brackets
    Dir.mktmpdir('shaka-codex') do |parent|
      home = FileUtils.mkdir_p(File.join(parent, 'reviewer[local]')).first
      copy = Shaka::LocalReviewCodexHome.keep_session(saved_session(home), home)
      assert_includes File.read(copy), '01a0d246-e758-7052-92bc-95afb12a6f60'
    ensure
      File.unlink(copy) if copy
    end
  end

  private

  def failing(owner, name, error)
    original = owner.method(name)
    owner.define_singleton_method(name) { |*| raise error }
    yield
  ensure
    owner.define_singleton_method(name, original)
  end
end
