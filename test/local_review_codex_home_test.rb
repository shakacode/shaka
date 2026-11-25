# frozen_string_literal: true

require_relative 'local_review_test'

# Codex reads AGENTS.md from CODEX_HOME even with --ignore-rules --ignore-user-config (#1198).
class LocalReviewCodexHomeTest < Minitest::Test
  include LocalReviewFixture

  COMMAND = LocalReviewCodexTest::COMMAND
  SUGGESTION = '`$review-agent` fits this task. Choose it, or ask me to proceed.'
  SIGNED_IN = %({"tokens":"first"}\n)
  REFRESHED = %({"tokens":"refreshed"}\n)
  THREAD = '01a0d246-e758-7052-92bc-95afb12a6f60'

  # Answers like the hijacked reviewer whenever a global AGENTS.md is visible in its home, saves
  # and announces a session, and can replace its sign-in link the way a rename-based refresh would.
  FAKE_CODEX = <<~'SCRIPT'
    #!/usr/bin/env ruby
    require 'fileutils'
    require 'json'
    STDIN.read
    plan = JSON.parse(File.read(File.join(__dir__, 'codex-plan.json')))
    auth = File.join(home = ENV.fetch('CODEX_HOME'), 'auth.json')
    trace = JSON.generate(home:, auth: File.exist?(auth) && File.read(auth))
    File.write(File.join(plan['trace_dir'], 'trace.json'), trace)
    File.write(File.realpath(auth), plan['concurrent']) if plan['concurrent']
    File.unlink(auth) && File.write(auth, plan['replacement']) if plan['replacement']
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
      refute_equal home, trace.fetch('home')
      assert_equal SIGNED_IN, trace.fetch('auth')
      refute_path_exists trace.fetch('home')
      assert_equal Dir.glob(File.join(home, 'sessions', '*', '*', '*', '*.jsonl')), [result.fetch('usage')]
    end
  end

  # Break caught: a token refresh that replaces auth.json would stay in the deleted temporary home
  # and leave the user's own sign-in with a used refresh token.
  def test_replaced_sign_in_file_is_written_back
    review_with_codex_home(replacement: REFRESHED) do |home|
      assert_equal REFRESHED, File.read(File.join(home, 'auth.json'))
      assert_equal 0o600, File.stat(File.join(home, 'auth.json')).mode & 0o777
    end
  end

  # Break caught: a truncated replacement from a killed reviewer overwrote the user's sign-in.
  def test_incomplete_replacement_leaves_the_sign_in_alone
    review_with_codex_home(replacement: '{"tokens":') do |home|
      assert_equal SIGNED_IN, File.read(File.join(home, 'auth.json'))
    end
  end

  # Break caught: another Codex process refreshed the real file during the review, and the
  # reviewer's older copy replaced it.
  def test_concurrent_refresh_of_the_real_sign_in_wins
    review_with_codex_home(replacement: REFRESHED, concurrent: %({"tokens":"other"}\n)) do |home|
      assert_equal %({"tokens":"other"}\n), File.read(File.join(home, 'auth.json'))
    end
  end

  # Break caught: with no real home yet, the session stayed in the deleted temporary home and
  # review usage read UNKNOWN.
  def test_session_is_kept_when_the_real_home_does_not_exist_yet
    with_repository do |root, base, head, bin|
      Dir.mktmpdir('shaka-codex-parent') do |parent|
        home = File.join(parent, 'codex')
        review_in(home, [root, base, head, bin], trace_dir: parent) do |result|
          assert_equal Dir.glob(File.join(home, 'sessions', '*', '*', '*', '*.jsonl')), [result.fetch('usage')]
        end
      end
    end
  end

  private

  def review_in(home, repository, **)
    root, base, head, bin = repository
    fake_codex_reading_home(bin, head, **)
    output, error, status = run_review(root, base, head, bin, env: { 'CODEX_HOME' => home })
    yield result = assert_successful_review(output, error, status, head, 'openai/codex')
  ensure
    cleanup_artifacts(result)
  end

  def review_with_codex_home(**)
    with_repository do |root, base, head, bin|
      with_user_home do |home|
        review_in(home, [root, base, head, bin], trace_dir: home, **) { |result| yield home, result }
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

  def fake_codex_reading_home(bin, head, trace_dir:, replacement: nil, concurrent: nil)
    plan = { trace_dir:, replacement:, concurrent:, thread: THREAD, review: attestation(head), hijack: SUGGESTION }
    File.write(File.join(bin, 'codex-plan.json'), JSON.generate(plan))
    write_executable(bin, 'codex', FAKE_CODEX)
  end

  def attestation(head) = "REVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\n"
end
