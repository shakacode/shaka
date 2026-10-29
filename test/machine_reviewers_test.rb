# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'
require_relative 'repository_fixture'
require 'shaka/configuration/machine_reviewers'

# Builds a home directory holding ~/.agents/shaka/local-reviewers.yml.
module MachineReviewersFixture
  def with_home(reviewers, version: 1)
    Dir.mktmpdir('shaka-home') do |home|
      text = reviewers.is_a?(String) ? reviewers : YAML.dump('version' => version, 'reviewers' => reviewers)
      write_list(home, text) if reviewers
      yield home
    end
  end

  def write_list(home, text)
    path = File.join(home, '.agents/shaka/local-reviewers.yml')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  # Code that reads the list through Dir.home sees this home directory.
  def with_env_home(home)
    original = Dir.home
    ENV['HOME'] = home
    yield
  ensure
    ENV['HOME'] = original
  end

  def claude(settings = {}) = { 'provider' => 'anthropic', 'model_family' => 'claude' }.merge(settings)
  def codex(settings = {}) = { 'provider' => 'openai', 'model_family' => 'codex' }.merge(settings)
  def grok = { 'provider' => 'xai', 'model_family' => 'grok', 'model' => 'grok-4.7' }
  def deepseek = { 'provider' => 'deepseek', 'model_family' => 'openrouter', 'model' => 'deepseek/deepseek-v4.1-flash' }
end

class MachineReviewersTest < Minitest::Test
  include MachineReviewersFixture

  Machine = Shaka::Configuration::MachineReviewers

  def test_an_absent_file_lists_nothing
    with_home(nil) { |home| assert_nil Machine.load(home:) }
    assert_nil Machine.load(home: nil)
  end

  def test_lists_reviewers_by_provider_and_model_family
    with_home([claude('model' => 'claude-opus-5-5'), codex]) do |home|
      machine = Machine.load(home:)

      assert machine.listed?('Anthropic/Claude')
      refute machine.listed?('xai/grok')
    end
  end

  # The repository's value wins; the machine fills only what it leaves unset.
  def test_fills_only_values_the_repository_entry_leaves_unset
    with_home([claude('model' => 'claude-opus-5-5', 'effort' => 'high')]) do |home|
      machine = Machine.load(home:)

      assert_equal({ 'model' => 'claude-opus-5-5', 'effort' => 'high' }, machine.fill(claude, 'anthropic/claude'))
      assert_equal({ 'effort' => 'high' }, machine.fill(claude('model' => 'claude-fable-5-1'), 'anthropic/claude'))
      assert_empty machine.fill(nil, 'openai/codex')
    end
  end

  def test_refuses_a_malformed_file_and_names_it
    {
      [claude, claude('model' => 'claude-opus-5-5')] => 'more than once',
      [claude('effort' => 3)] => 'effort must be a level name',
      [claude('prompt' => 'x')] => 'unknown key prompt',
      "reviewers: [\n" => 'not valid YAML'
    }.each { |reviewers, message| assert_malformed(reviewers, message) }
  end

  def test_refuses_another_version
    assert_malformed([claude], 'version', version: 2)
  end

  private

  def assert_malformed(reviewers, message, version: 1)
    with_home(reviewers, version:) do |home|
      error = assert_raises(Shaka::Error) { Machine.load(home:) }
      assert_includes error.message, message
      assert_includes error.message, '.agents/shaka/local-reviewers.yml'
    end
  end
end

class MachineReviewersDoctorTest < Minitest::Test
  include MachineReviewersFixture
  include DoctorHelper
  include RepositoryConfigTestHelpers

  # Without coverage, the file narrows notices to the reviewers this machine expects.
  def test_without_coverage_only_listed_reviewers_warn
    review = review_policy('local_review_agents' => [claude, codex, deepseek])
    with_repository('review' => review) do |root|
      with_home([claude, codex]) do |home|
        report, = doctor(root:, environment: { 'HOME' => home })

        assert_includes report, '[HEALTHY] Reviewer CLIs'
        assert_includes report, 'Machine reviewers: anthropic/claude, openai/codex expected on this machine'
      end
    end
  end

  # With coverage, listing an uncovered reviewer brings its warning back.
  def test_listing_an_uncovered_reviewer_restores_its_warning
    review = review_policy('provider_coverage' => %w[anthropic openai], 'local_review_agents' => [claude, codex, grok])
    with_repository('review' => review) do |root|
      with_home([grok]) do |home|
        report, = doctor(root:, environment: { 'HOME' => home }, executable: ->(name, *) { name != 'grok' })

        assert_includes report, '[DEGRADED] Reviewer CLIs'
        assert_includes report, 'This repository configures xai/grok reviews, but local setup is incomplete.'
      end
    end
  end

  # The file cannot quiet a covered provider.
  def test_a_covered_reviewer_warns_even_when_unlisted
    review = review_policy('provider_coverage' => %w[anthropic openai], 'local_review_agents' => [claude, codex])
    with_repository('review' => review) do |root|
      with_home([claude]) do |home|
        report, = doctor(root:, environment: { 'HOME' => home }, executable: ->(name, *) { name != 'codex' })

        assert_includes report, 'This repository configures openai/codex reviews, but local setup is incomplete.'
      end
    end
  end

  # One file serves every repository, so an entry another repository uses stays informational.
  def test_an_unmatched_entry_is_informational
    review = review_policy('local_review_agents' => [claude, codex])
    with_repository('review' => review) do |root|
      with_home([claude, codex, grok]) do |home|
        report, = doctor(root:, environment: { 'HOME' => home })

        assert_includes report, '[HEALTHY] Reviewer CLIs'
        assert_includes report, 'xai/grok in the machine reviewer list is not configured by this repository'
      end
    end
  end

  def test_a_malformed_file_degrades_and_names_the_path
    review = review_policy('local_review_agents' => [claude, codex])
    with_repository('review' => review) do |root|
      with_home([claude, claude]) do |home|
        report, = doctor(root:, environment: { 'HOME' => home })

        assert_includes report, '[DEGRADED] Reviewer CLIs'
        assert_includes report, "#{home}/.agents/shaka/local-reviewers.yml"
      end
    end
  end
end

require_relative 'review_agent_settings_test'

class MachineReviewersRunTest < Minitest::Test
  include MachineReviewersFixture
  include ReviewAgentSettingsFixture

  def test_machine_model_and_effort_fill_what_the_repository_leaves_unset
    with_repository(codex_agent('effort' => 'medium')) do |*checkout|
      with_home([codex('model' => 'gpt-6-astra', 'effort' => 'high')]) do |home|
        args = machine_arguments(checkout, home)

        assert_equal 'gpt-6-astra', args.fetch(args.index('-m') + 1)
        assert_includes args, 'model_reasoning_effort="medium"'
      end
    end
  end

  def test_a_task_choice_wins_over_the_machine
    with_repository(codex_agent({})) do |*checkout|
      with_home([codex('model' => 'gpt-6-astra')]) do |home|
        args = machine_arguments(checkout, home, '--model', 'gpt-6-sol')

        assert_equal 'gpt-6-sol', args.fetch(args.index('-m') + 1)
      end
    end
  end

  # Break caught: a reviewer the repository does not list took the machine's model.
  def test_an_unlisted_reviewer_gets_no_machine_values
    with_repository do |*checkout|
      with_home([codex('model' => 'gpt-6-astra')]) do |home|
        refute_includes machine_arguments(checkout, home), '-m'
      end
    end
  end

  def test_a_malformed_machine_file_refuses_to_start
    with_repository(codex_agent({})) do |*checkout|
      with_home([codex, codex]) do |home|
        output, _error, status = run_with_home(checkout, home)

        refute_predicate status, :success?
        assert_includes JSON.parse(output).fetch('reason'), 'local-reviewers.yml'
      end
    end
  end

  private

  def run_with_home(checkout, home, *options)
    root, base, head, bin = checkout
    Open3.capture3({ 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'REVIEW_TRACE' => File.join(root, 'trace.json'),
                     'HOME' => home },
                   *COMMAND, 'review', 'run', '--root', root, '--base', base, '--head', head,
                   '--reviewer', 'openai/codex', '--criteria-ref', base, *options)
  end

  def machine_arguments(checkout, home, *options)
    output, error, status = run_with_home(checkout, home, *options)
    assert_predicate status, :success?, "#{output}\n#{error}"
    File.unlink(JSON.parse(output).fetch('report'))
    JSON.parse(File.read(File.join(checkout.first, 'trace.json'))).fetch('args')
  end
end

require_relative 'evidence_fixture'

class MachineReviewersEvidenceTest < Minitest::Test
  include MachineReviewersFixture
  include EvidenceFixture

  # Evidence replays the recorded machine values, so another machine's file never supersedes it.
  def test_review_evidence_records_machine_values_and_binds_without_the_file
    with_checkout do |root, ref|
      list = [codex('model' => 'gpt-6-astra', 'effort' => 'high')]
      result = with_home(list) { |home| review_with_home(root, ref, home) }

      assert_equal({ 'reviewer' => 'openai/codex', 'machine_model' => 'gpt-6-astra', 'machine_effort' => 'high' },
                   result.fetch('task_overrides'))
      assert_equal %w[REDACTED high],
                   result.fetch('public_settings').values_at('overrides.machine_model', 'overrides.machine_effort')
      bound = with_home(nil) { |home| with_env_home(home) { bind(root, ref, ref, result) } }
      assert_equal 'bound', bound.fetch('status')
    end
  end

  # A task choice wins, so the machine value it replaces is not recorded.
  def test_review_evidence_skips_machine_values_the_task_replaces
    with_checkout do |root, ref|
      result = with_home([codex('model' => 'gpt-6-astra', 'effort' => 'high')]) do |home|
        review_with_home(root, ref, home, model: 'gpt-6-sol')
      end

      assert_equal({ 'reviewer' => 'openai/codex', 'model' => 'gpt-6-sol', 'machine_effort' => 'high' },
                   result.fetch('task_overrides'))
    end
  end

  # Break caught: the runner strips a padded identity and applies the machine model; evidence did not.
  def test_review_evidence_reads_a_padded_reviewer_like_the_run
    with_checkout do |root, ref|
      result = with_home([codex('model' => 'gpt-6-astra')]) do |home|
        review_with_home(root, ref, home, reviewer: ' OpenAI / Codex ')
      end

      assert_equal 'gpt-6-astra', result.fetch('task_overrides').fetch('machine_model')
    end
  end

  # Evidence records only what the run applies: an unlisted reviewer gets no machine values.
  def test_review_evidence_records_nothing_for_an_unlisted_reviewer
    with_checkout do |root, ref|
      result = with_home([grok]) { |home| review_with_home(root, ref, home, reviewer: 'xai/grok') }

      assert_equal({ 'reviewer' => 'xai/grok' }, result.fetch('task_overrides'))
    end
  end

  private

  def review_with_home(root, ref, home, reviewer: 'openai/codex', model: nil)
    with_env_home(home) do
      options = { root:, settings_ref: ref, repository: 'shakacode/shaka', reviewer:, model: }
      Shaka::Evidence::Review.start(options, action: 'run')
                             .finish('status' => 'completed', 'head' => ref, 'reviewer' => reviewer)
    end
  end
end

require_relative 'doctor_probe_test'

class MachineReviewersProbeTest < Minitest::Test
  include MachineReviewersFixture
  include DoctorHelper
  include RepositoryConfigTestHelpers
  include DoctorProbeFixture

  # Break caught: the startup probe checks the CLI default while reviews run the machine's model.
  def test_the_probe_uses_the_model_this_machine_fills_in
    with_probe do |root, path, trace|
      write_codex(path, trace, success: true)
      with_home([codex('model' => 'gpt-6-astra')]) { |home| with_env_home(home) { probe(root, path, agent: codex) } }

      assert_includes JSON.parse(File.read(trace)).fetch('args'), 'gpt-6-astra'
    end
  end
end
