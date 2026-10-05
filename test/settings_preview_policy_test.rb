# frozen_string_literal: true

require_relative 'settings_preview_fixture'
require_relative 'merge_test'
require 'shaka/seam'
require 'shaka/prefix'
require_relative 'claim_helpers'

class SettingsPreviewPolicyTest < Minitest::Test
  include SettingsPreviewFixture

  def test_selected_configuration_reaches_policy_readers_in_both_layouts
    %i[legacy new].each do |layout|
      with_preview_repository(layout:) do |root, trusted, preview|
        select_preview(root, preview)
        policy = Shaka::TrustedConfigSource.from_ref(root:, ref: trusted)
        report = check_report(root, trusted)
        assert_equal policy.to_h, report.except('validation')
        assert_equal({ 'mode' => 'preview/local', 'ref' => trusted, 'sha' => preview,
                       'grants_policy' => true, 'grants_merge_authority' => false }, report['validation'])
      end
    end
  end

  def test_unselected_candidate_cannot_change_policy
    with_preview_repository do |root, trusted, preview|
      git(root, 'checkout', preview, '--', '.agents/agent-workflow.yml')
      assert_equal 'ask', Shaka::TrustedConfigSource.from_ref(root:, ref: trusted).merge['preference']
      assert_equal 'trusted/team', Shaka::Evidence::Inputs.resolve_source(root, trusted).last
    end
  end

  def test_selected_merge_limits_replace_repository_defaults
    with_preview_repository do |root, trusted, _preview|
      path = File.join(root, '.agents/agent-workflow.yml')
      data = YAML.safe_load_file(path)
      data['merge']['limits'] = { 'max_changed_files' => 2 }
      File.write(path, YAML.dump(data))
      select_preview(root, commit(root))
      limits = Shaka::MergeLimits.from_ref(root:, ref: trusted)
      assert_equal 2, limits.to_h['max_changed_files']
    end
  end

  private

  def check_report(root, trusted)
    output, error, status = Open3.capture3(COMMAND, 'seam', 'check', '--root', root, '--ref', trusted)
    assert_predicate status, :success?, error
    JSON.parse(output)
  end
end

class SettingsPreviewNamingTest < Minitest::Test
  include SettingsPreviewFixture
  include ClaimHelpers

  def test_selected_prefix_and_branch_template_reach_task_naming
    with_preview_repository do |root, trusted, _preview|
      select_naming(root, trusted)
      assert_equal 'TRY', Shaka::Prefix.new(root:, ref: trusted).call['prefix']
      output, status = capture_cli(['1', '--root', root], prs: [], branches: '')
      assert_equal 0, status
      assert_equal 'trial/{issue}-{description}', JSON.parse(output)['branch_name']
    end
  end

  private

  def select_naming(root, trusted)
    git(root, 'update-ref', 'refs/remotes/origin/main', trusted)
    path = File.join(root, '.agents/agent-workflow.yml')
    data = YAML.safe_load_file(path).merge('repo_prefix' => 'TRY',
                                           'branches' => { 'name' => 'trial/{issue}-{description}' })
    File.write(path, YAML.dump(data))
    select_preview(root, commit(root))
  end
end

class SettingsPreviewNativeMergeTest < Minitest::Test
  include MergeFixtures
  include SettingsPreviewFixture

  def test_selected_review_opt_out_cannot_bypass_native_required_checks
    with_selected_merge do
      @client.checks = [{ 'name' => 'Required', 'state' => 'PENDING', 'bucket' => 'pending' }]
      assert_blocked(/Required check is not passing/)
    end
  end

  def test_selected_review_opt_out_cannot_bypass_native_approvals
    with_selected_merge do
      @client.snapshots = [snapshot.merge('reviewDecision' => 'REVIEW_REQUIRED')]
      assert_blocked(/Required reviews are not satisfied/)
    end
  end

  private

  def with_selected_merge
    with_preview_repository do |root, trusted, _preview|
      select_without_review(root)
      policy = Shaka::TrustedConfigSource.from_ref(root:, ref: trusted)
      @merge = Shaka::Merge.new(@client, seam_wait: policy.review['ci_review_wait'],
                                         review: { required: policy.review['required'] })
      yield
    end
  end

  def select_without_review(root)
    path = File.join(root, '.agents/agent-workflow.yml')
    data = YAML.safe_load_file(path)
    data['review'] = { 'required' => 'none', 'ci_review_wait' => 'none',
                       'post_implementation' => { 'enabled' => false } }
    File.write(path, YAML.dump(data))
    select_preview(root, commit(root))
  end
end
