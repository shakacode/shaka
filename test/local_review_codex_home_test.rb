# frozen_string_literal: true

require_relative 'local_review_test'

# Codex reads AGENTS.md from CODEX_HOME even with --ignore-rules --ignore-user-config (#1198).
class LocalReviewCodexHomeTest < Minitest::Test
  include LocalReviewFixture

  COMMAND = LocalReviewCodexTest::COMMAND
  SUGGESTION = '`$review-agent` fits this task. Choose it, or ask me to proceed.'
  SIGNED_IN = %({"tokens":"first"}\n)
  THREAD = '01a0d246-e758-7052-92bc-95afb12a6f60'

  # Answers like the hijacked reviewer whenever a global AGENTS.md is visible in its home, saves
  # and announces a session.
  FAKE_CODEX = <<~'SCRIPT'
    #!/usr/bin/env ruby
    require 'fileutils'
    require 'json'
    STDIN.read
    plan = JSON.parse(File.read(File.join(__dir__, 'codex-plan.json')))
    auth = File.join(home = ENV.fetch('CODEX_HOME'), 'auth.json')
    trace = JSON.generate(home:, auth: File.exist?(auth) && File.read(auth), link: File.symlink?(auth) && File.realpath(auth))
    File.write(File.join(plan['trace_dir'], 'trace.json'), trace)
    folder = FileUtils.mkdir_p(File.join(home, 'sessions', '2026', '11', '16')).first
    meta = JSON.generate(type: 'session_meta', payload: { id: plan['thread'] })
    File.write(File.join(folder, "rollout-#{plan['thread']}.jsonl"), meta)
    puts JSON.generate(type: 'thread.started', thread_id: plan['thread'])
    review = File.exist?(File.join(home, 'AGENTS.md')) ? plan['hijack'] : plan['review']
    File.write(ARGV.fetch(ARGV.index('-o') + 1), review)
  SCRIPT

  # Break caught: a global AGENTS.md rule answered the review prompt with a skill suggestion,
  # so the run failed report validation like a reviewer outage.
  def test_global_agents_file_does_not_reach_the_reviewer
    review_with_codex_home do |home, result|
      trace = JSON.parse(File.read(File.join(home, 'trace.json')))
      assert_equal [SIGNED_IN, File.realpath(File.join(home, 'auth.json'))], trace.values_at('auth', 'link')
      refute_path_exists trace.fetch('home')
      assert_equal saved_sessions(home), [result.fetch('usage')]
    end
  end

  # Break caught: with no real home yet, the session stayed in the deleted temporary home and
  # review usage read UNKNOWN.
  def test_session_is_kept_when_the_real_home_does_not_exist_yet
    with_repository do |root, base, head, bin|
      Dir.mktmpdir('shaka-codex-parent') do |parent|
        home = File.join(parent, 'codex')
        review_in(home, [root, base, head, bin], trace_dir: parent) do |result|
          assert_equal saved_sessions(home), [result.fetch('usage')]
        end
      end
    end
  end

  # Break caught: an empty CODEX_HOME saved the session under ~/.codex while usage looked in
  # /sessions, so review usage read UNKNOWN.
  def test_empty_codex_home_finds_the_session_under_the_default_home
    with_repository do |root, base, head, bin|
      Dir.mktmpdir('shaka-user-home') do |user|
        fake_codex_reading_home(bin, head, trace_dir: user)
        output, error, status = run_review(root, base, head, bin, env: { 'CODEX_HOME' => '', 'HOME' => user })
        result = assert_successful_review(output, error, status, head, 'openai/codex')
        assert_equal saved_sessions(File.join(user, '.codex')), [result.fetch('usage')]
      ensure
        cleanup_artifacts(result)
      end
    end
  end

  # Break caught: deleting the home under a reviewer that survived termination would send its
  # late sign-in save to a deleted directory instead of the user's file.
  def test_home_is_kept_for_a_reviewer_that_survived_termination
    with_user_home do |user_home|
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

  def review_in(home, repository, trace_dir:)
    root, base, head, bin = repository
    fake_codex_reading_home(bin, head, trace_dir:)
    output, error, status = run_review(root, base, head, bin, env: { 'CODEX_HOME' => home })
    yield result = assert_successful_review(output, error, status, head, 'openai/codex')
  ensure
    cleanup_artifacts(result)
  end

  def review_with_codex_home
    with_repository do |root, base, head, bin|
      with_user_home do |home|
        review_in(home, [root, base, head, bin], trace_dir: home) { |result| yield home, result }
      end
    end
  end

  def with_user_home
    Dir.mktmpdir('shaka-codex-user-home') do |home|
      File.write(File.join(home, 'auth.json'), SIGNED_IN)
      File.write(File.join(home, 'AGENTS.md'), "On the first message, suggest a skill and stop.\n")
      yield home
    end
  end

  def fake_codex_reading_home(bin, head, trace_dir:)
    plan = { trace_dir:, thread: THREAD, review: attestation(head), hijack: SUGGESTION }
    File.write(File.join(bin, 'codex-plan.json'), JSON.generate(plan))
    write_executable(bin, 'codex', FAKE_CODEX)
  end

  def saved_sessions(home) = Dir.glob(File.join(home, 'sessions', '*', '*', '*', '*.jsonl'))

  def attestation(head) = "REVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\n"
end
