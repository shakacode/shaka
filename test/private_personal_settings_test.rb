# frozen_string_literal: true

require_relative 'private_seed_test'

# Builds a home directory holding ~/.agents/shaka/config.yml and points Dir.home at it.
module PersonalSettingsFixture
  include PrivateSeedFixture

  PREFERENCES = {
    'version' => 1,
    'review' => { 'local_review_agents' => [{ 'provider' => 'openai', 'model_family' => 'codex', 'effort' => 'high' }],
                  'local_max_rounds' => 3 },
    'prose_limits' => { 'max_sentence_words' => 30 },
    'pr_description' => { 'opening_check' => { 'enabled' => false } },
    'wip' => { 'include_checkout_path' => false }
  }.freeze

  def with_personal(settings = PREFERENCES)
    Dir.mktmpdir('shaka-home') do |home|
      write_personal(home, settings) if settings
      original = Dir.home
      ENV['HOME'] = home
      yield File.join(home, '.agents/shaka/config.yml')
    ensure
      ENV['HOME'] = original
    end
  end

  def write_personal(home, settings)
    path = File.join(home, '.agents/shaka/config.yml')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, settings.is_a?(String) ? settings : YAML.dump(settings))
  end

  def setup_with(root, ref, **extra) = Shaka::Seam::PrivateSetup.new(root:, ref:, options: options.merge(extra))
  def written(root) = YAML.safe_load_file(config_path(root))

  def assert_nothing_written(root)
    refute_path_exists File.join(root, '.agents/shaka')
    assert_nil Shaka::Seam::PrivateRecovery.new(root:, assign_identity: false).storage
  end

  def assert_preferences_written(root)
    config = written(root)
    assert_equal PREFERENCES['review']['local_review_agents'], config['review']['local_review_agents']
    assert_equal({ 'max_sentence_words' => 30 }, config['prose_limits'])
    refute config['wip']['include_checkout_path']
    assert_equal 'none', config['review']['required']
  end

  def interrupt(setup)
    setup.define_singleton_method(:write_new_file) { |file, _| raise Errno::EIO, file }
    assert_raises(Shaka::Error) { setup.setup }
  end

  def adopt_team_settings(root)
    Shaka::Seam::Initializer.new(root: File.realpath(root), options:).call
    refute written(root).key?('prose_limits')
    git(root, 'add', '-f', '.agents')
    git(root, 'commit', '--quiet', '-m', 'adopt team settings')
  end
end

class PrivatePersonalSettingsTest < Minitest::Test
  include PersonalSettingsFixture

  def test_personal_preferences_pre_fill_setup_while_commands_come_from_flags
    with_setup do |root, ref|
      with_personal do |path|
        result = setup_with(root, ref).setup
        assert_preferences_written(root)
        assert_equal path, result.fetch('prefilled_from')
        assert_includes result.fetch('prefilled_keys'), 'pr_description.opening_check.enabled'
        assert_equal 'complete', Shaka::Configuration.private_source(root:, ref:).status
      end
    end
  end

  def test_an_absent_file_and_the_skip_flag_both_write_todays_configuration
    expected = with_setup { |root, ref| with_personal(nil) { setup_with(root, ref).setup.then { written(root) } } }
    with_setup do |root, ref|
      with_personal do
        result = setup_with(root, ref, no_personal_file: true).setup
        assert_equal expected, written(root)
        refute result.key?('prefilled_keys')
      end
    end
  end

  def test_a_repository_fact_stops_setup_naming_the_file_and_key
    with_setup do |root, ref|
      with_personal(PREFERENCES.merge('merge' => { 'preference' => 'auto' })) do |path|
        error = assert_raises(Shaka::Error) { setup_with(root, ref).setup }
        assert_includes error.message, "#{path} cannot set merge"
        assert_nothing_written(root)
      end
    end
  end

  def test_a_prompt_file_on_a_reviewer_entry_is_refused
    entry = { 'provider' => 'openai', 'model_family' => 'codex', 'replacement_prompt_file' => 'review.md' }
    with_setup do |root, ref|
      with_personal('version' => 1, 'review' => { 'local_review_agents' => [entry] }) do |path|
        error = assert_raises(Shaka::Error) { setup_with(root, ref).setup }
        assert_includes error.message, "#{path} cannot set review.local_review_agents[0].replacement_prompt_file"
        assert_nothing_written(root)
      end
    end
  end

  def test_an_invalid_or_linked_value_names_the_file
    with_setup do |root, ref|
      linked = { 'version' => 1, 'pr_description' => { 'opening_check' => { 'model' => 'gpt-6.1-sol' } } }
      [linked, "version: 2\n", ''].each do |settings|
        with_personal(settings) do |path|
          error = assert_raises(Shaka::Error) { setup_with(root, ref).setup }
          assert_includes error.message, path
          assert_nothing_written(root)
        end
      end
    end
  end

  MALFORMED_REVIEWERS = {
    'checkpoint.reviewer' => { 'version' => 1, 'checkpoint' => { 'reviewer' => 'codex' } },
    'pr_description.opening_check.reviewer' => { 'version' => 1,
                                                 'pr_description' => { 'opening_check' => { 'reviewer' => nil } } }
  }.freeze

  def test_a_malformed_reviewer_identity_names_its_key
    with_setup do |root, ref|
      MALFORMED_REVIEWERS.each do |key, settings|
        with_personal(settings) do |path|
          assert_includes assert_raises(Shaka::Error) { setup_with(root, ref).setup }.message, "#{path} #{key}:"
        end
      end
    end
  end

  def test_a_reviewer_flag_replaces_the_personal_reviewer_list
    with_setup do |root, ref|
      with_personal do
        flag = [Shaka::ReviewerSelection.parse('anthropic/claude')]
        setup_with(root, ref, local_review_agents: flag).setup
        assert_equal [{ 'provider' => 'anthropic', 'model_family' => 'claude' }],
                     written(root)['review']['local_review_agents']
        assert_equal 3, written(root)['review']['local_max_rounds']
      end
    end
  end

  def test_plan_returns_the_proposal_and_writes_nothing
    with_setup do |root, ref|
      exclude = File.read(File.join(root, '.git/info/exclude'))
      with_personal do |path|
        plan = setup_with(root, ref).plan
        assert_equal path, plan.fetch('prefilled_from')
        assert_includes plan.fetch('config'), 'max_sentence_words: 30'
        assert_nothing_written(root)
        assert_equal exclude, File.read(File.join(root, '.git/info/exclude'))
      end
    end
  end
end

# Places where Shaka must never read the personal file: each test makes it invalid YAML.
class PrivatePersonalSettingsBoundaryTest < Minitest::Test
  include PersonalSettingsFixture

  def test_seeding_from_another_worktree_ignores_the_file
    with_seed_source do |root, ref, id|
      with_linked_worktree(root) do |worktree|
        with_personal("not: [valid\n") { seed(worktree, ref, id) }
        assert_seeded(worktree, ref)
      end
    end
  end

  def test_team_setup_and_task_time_resolution_never_read_the_file
    with_setup do |root, ref|
      with_personal("not: [valid\n") do
        assert_equal 'absent', Shaka::Configuration.private_source(root:, ref:).status
        adopt_team_settings(root)
        _, _, kind = Shaka::Configuration.resolve_source(root:, ref: head(root))
        assert_equal 'trusted/team', kind
      end
    end
  end

  def test_private_setup_on_a_team_repository_refuses_without_reading_the_file
    with_setup do |root, _ref|
      adopt_team_settings(root)
      with_personal("not: [valid\n") do
        %i[setup plan].each do |run|
          error = assert_raises(Shaka::Error) { setup_with(root, head(root)).public_send(run) }
          assert_includes error.message, 'Trusted Shaka configuration already exists'
        end
      end
    end
  end

  def test_individual_settings_resolve_without_reading_the_file
    with_setup do |root, ref|
      with_personal { setup_with(root, ref).setup }
      with_personal("not: [valid\n") do
        _, _, kind = Shaka::Configuration.resolve_source(root:, ref:)
        assert_equal 'private/local', kind
      end
    end
  end

  def test_cli_plans_and_skips_the_personal_file
    with_setup do |root, ref|
      with_personal do
        output, = capture_io { assert_equal 0, Shaka::Seam.run([*cli_setup_args(root, ref), '--plan']) }
        assert_equal 'plan', JSON.parse(output).fetch('status')
        assert_nothing_written(root)
        output, = capture_io { Shaka::Seam.run([*cli_setup_args(root, ref), '--no-personal-file']) }
        refute JSON.parse(output).key?('prefilled_keys')
      end
    end
  end

  def test_a_completed_clone_never_reads_the_file
    with_setup do |root, ref|
      with_personal(nil) { setup_with(root, ref).setup }
      with_personal("not: [valid\n") do
        assert_equal 'complete', setup_with(root, ref).setup.fetch('status')
        assert_equal 'plan', setup_with(root, ref).plan.fetch('status')
      end
    end
  end
end

# How setup explains a refusal the personal file may have caused, and the per-run skip.
class PrivatePersonalSettingsRefusalTest < Minitest::Test
  include PersonalSettingsFixture

  def refusal(root, ref, run) = assert_raises(Shaka::Error) { setup_with(root, ref).public_send(run) }.message

  def test_a_rerun_on_a_pre_filled_clone_names_the_next_step
    with_setup do |root, ref|
      with_personal do
        setup_with(root, ref).setup
        %i[setup plan].each do |run|
          assert_includes refusal(root, ref, run), 'change .agents/shaka/config.yml directly'
        end
      end
    end
  end

  def test_a_resume_after_the_file_changed_names_the_file_in_plan_and_setup
    with_setup do |root, ref|
      with_personal do |path|
        interrupt(setup_with(root, ref))
        File.write(path, YAML.dump(PREFERENCES.merge('prose_limits' => { 'max_sentence_words' => 20 })))
        %i[setup plan].each do |run|
          assert_includes refusal(root, ref, run), "#{path} may have changed"
        end
      end
    end
  end

  def test_a_resume_with_a_different_skip_choice_names_that_cause
    with_setup do |root, ref|
      with_personal do
        interrupt(setup_with(root, ref))
        error = assert_raises(Shaka::Error) { setup_with(root, ref, no_personal_file: true).setup }
        assert_includes error.message, 'rerun without --no-personal-file'
      end
    end
  end

  def test_plan_refuses_an_unwritable_destination_like_setup
    skip 'root can write to any directory' if Process.uid.zero?
    with_setup do |root, ref|
      FileUtils.mkdir_p(File.join(root, '.agents'))
      File.chmod(0o555, File.join(root, '.agents'))
      with_personal do
        %i[plan setup].each { |run| assert_includes refusal(root, ref, run), 'is not writable' }
      end
    ensure
      File.chmod(0o755, File.join(root, '.agents'))
    end
  end

  def test_plan_on_an_unchanged_interrupted_setup_can_resume
    with_setup do |root, ref|
      with_personal do
        interrupt(setup_with(root, ref))
        assert_equal 'plan', setup_with(root, ref).plan.fetch('status')
        assert_equal 'complete', setup_with(root, ref).setup.fetch('status')
      end
    end
  end

  def test_the_skip_flag_passes_a_broken_file
    with_setup do |root, ref|
      with_personal("not: [valid\n") do
        assert_equal 'plan', setup_with(root, ref, no_personal_file: true).plan.fetch('status')
        assert_equal 'complete', setup_with(root, ref, no_personal_file: true).setup.fetch('status')
      end
    end
  end
end
