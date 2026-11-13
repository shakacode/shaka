# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/evidence/phase_log'
require 'shaka/publication/measured_steps'
require 'shaka/publication/timeline_steps'

# A validation command reports its own phases, and only phases of the recorded shape reach the result.
class PhaseLogTest < Minitest::Test
  include EvidenceFixture

  PhaseLog = Shaka::Evidence::PhaseLog

  def test_evidence_run_returns_the_phases_its_command_reported
    with_checkout do |root, _ref|
      write_test_command(root, <<~SH)
        printf '{"phase":"tests","duration_ms":4000}\\n' >> "$SHAKA_PHASE_LOG"
        printf 'not json\\n{"phase":"Bad Name","duration_ms":5}\\n' >> "$SHAKA_PHASE_LOG"
        printf '{"phase":"rubocop","duration_ms":1500}\\n{"phase":"tests","duration_ms":1000}\\n' >> "$SHAKA_PHASE_LOG"
      SH
      git(root, 'add', '-A')
      commit(root)

      result = run_check(root, git(root, 'rev-parse', 'HEAD'))

      assert_equal({ 'tests' => 5000, 'rubocop' => 1500 }, result.fetch('phases'))
    end
  end

  def test_a_command_that_reports_nothing_adds_no_phases
    with_checkout do |root, ref|
      refute run_check(root, ref).key?('phases')
    end
  end

  def test_sanitize_keeps_short_names_and_whole_milliseconds_up_to_the_cap
    phases = [['tests', 10], ['a' * 25, 1], ['x', -1], ['y', 1.5], [:z, 1], ['huge', 10**400],
              ['tests', Shaka::Phases::MAX_MS], ['tests', -5],
              *('a'..'j').map { |name| [name, 1] }]

    kept = Shaka::Phases.sanitize(phases)

    assert_equal Shaka::Phases::MAX_PHASES, kept.size
    assert_equal 10, kept['tests']
    assert_equal %w[tests a b c d e f g], kept.keys
  end

  def test_combining_runs_keeps_every_name_each_run_reported
    first = ('a'..'h').to_h { |name| [name, 1] }

    steps = [step('a', 9000, phases: first), step('b', 9000, phases: { 'tests' => 5000 })]
    text = Shaka::MeasuredSteps.new(Shaka::TimeZone::UTC).parts(steps, 0, charted: true).compact.join("\n")

    assert_includes text, 'h 0s · tests 5s'
  end

  def test_a_phase_file_replaced_by_a_pipe_is_not_read
    skip 'Windows has no named pipes in the file system' unless File.respond_to?(:mkfifo) && !Gem.win_platform?
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'phases.jsonl')
      File.mkfifo(path)

      assert_equal({}, PhaseLog.read(path))
    end
  end

  def test_measured_steps_add_up_phases_and_name_machine_sleep
    steps = [step('a', 600_000, awake: 300_000, phases: { 'tests' => 400_000, 'rubocop' => 100_000 }),
             step('b', 120_000, phases: { 'tests' => 100_000 }), step('c', 60_000)]

    text = Shaka::MeasuredSteps.new(Shaka::TimeZone::UTC).parts(steps, 0, charted: true).compact.join("\n")

    assert_includes text, '**Validation phases:** tests 8m 20s · rubocop 1m 40s ' \
                          '(2 of 3 validation runs reported phases)'
    assert_includes text, '**Machine asleep during steps:** 5m 0s, included in the times above'
  end

  def test_carried_steps_keep_phases_and_awake_time_but_never_the_session
    record = step('a', 9000, awake: 8000, phases: { 'tests' => 7000, 'Bad' => 1 })
             .merge('session' => '01234567-89ab-cdef-0123-456789abcdef', 'awake_ms' => 8000)

    checked = Shaka::TimelineSteps.checked(record)

    assert_equal({ 'tests' => 7000 }, checked['phases'])
    assert_equal 8000, checked['awake_ms']
    refute checked.key?('session')
    assert_nil Shaka::TimelineSteps.checked(record.merge('awake_ms' => 10_000))['awake_ms']
  end

  private

  def write_test_command(root, body)
    path = File.join(root, '.agents/shaka/bin/test')
    File.write(path, "#!/bin/sh\n#{body}exit 0\n")
    File.chmod(0o755, path)
  end

  def step(id, duration, awake: nil, phases: nil)
    { 'id' => id.ljust(16, '0'), 'command' => 'evidence run', 'check' => 'validate', 'at' => '2026-11-08T10:00:00Z',
      'duration_ms' => duration, 'exit' => 0, 'awake_ms' => awake, 'phases' => phases }.compact
  end
end
