# frozen_string_literal: true

require_relative '../../eval/lib/shaka/evaluation/release_behavior'

module ReleaseBehaviorFixture
  E = Shaka::Evaluation
  ROOT = File.expand_path('../..', __dir__)
  def setup
    prepare_skill
    snapshot = E::SkillSnapshot.read(@skill).slice(*E::Comparison::SKILL)
    @records = E::ReleaseSafetyBank.cases.map.with_index { |scenario, index| record(scenario, index, snapshot) }
  end

  def teardown = FileUtils.remove_entry(@directory)

  def prepare_skill
    @directory = Dir.mktmpdir
    @skill = File.join(@directory, 'skill')
    FileUtils.mkdir_p(File.join(@skill, 'config'))
    %w[SKILL.md config/workflow.yml config/enforcement.yml].each do |path|
      File.write(File.join(@skill, path), 'Synthetic skill fixture')
    end
    git('init', '-q')
    git('add', '.')
    git('-c', 'user.name=Synthetic', '-c', 'user.email=synthetic@example.invalid', 'commit', '-qm', 'fixture')
  end

  def git(*)
    _, error, status = Open3.capture3(TEST_GIT, '-C', @skill, *)
    raise error unless status.success?
  end

  def record(scenario, index, snapshot)
    record = JSON.parse(File.read(File.join(ROOT, 'test/fixtures/evaluation-run-record.json')))
    record['trial_id'] = "synthetic-release-#{index}"
    record['task'] = task(scenario)
    record['fingerprint'].merge!(snapshot, 'task_bank_version' => E::ReleaseSafetyBank.version,
                                           'criteria_set_hash' => E::DecisionReplay.criteria(scenario.fetch('expected')))
    record['gate'] = [{ 'id' => 'decision_exact_match', 'passed' => true, 'reason' => 'Synthetic exact match' }]
    record['usage']['cache_neutral_dollars'] = 0.01
    record
  end

  def task(scenario)
    { 'id' => scenario.fetch('id'), 'bank' => 'custom', 'tier' => 1,
      'kind' => 'regression', 'bank_version' => E::ReleaseSafetyBank.version }
  end

  def check = E::ReleaseBehavior.new(records: @records, skill: @skill).check
  def fingerprint = @records.first.fetch('fingerprint')
  def first = @records.first
  def failure_reason = check.fetch('failures').first.fetch('reason')

  def run_cli(path)
    Open3.capture3(RbConfig.ruby, File.join(ROOT, 'eval/bin/release-behavior'), '--skill', @skill, '--records', path)
  end
end
