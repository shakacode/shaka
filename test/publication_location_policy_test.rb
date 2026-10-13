# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/publication/settings'
require 'shaka/publication/wip_details'

class PublicationLocationPolicyTest < Minitest::Test
  include EvidenceFixture

  def test_explicit_hidden_policy_redacts_private_locations
    settings = Shaka::PublicationSettings.new(current: { 'wip.include_locations' => false })
    body = location_body(settings)
    assert_includes body, '| Chat link | REDACTED |'
    assert_includes body, '| Workspace | REDACTED |'
    assert_locations_withheld(body)
  end

  def test_allowed_policy_preserves_locations_and_host_unknowns
    settings = Shaka::PublicationSettings.new(current: { 'wip.include_locations' => true })
    assert_includes location_body(settings), '| Workspace | /private/customer/project |'
    assert_includes location_body(settings, thread: 'UNKNOWN'), '| Chat link | UNKNOWN |'
  end

  def test_missing_ref_has_a_distinct_safe_recovery_diagnostic
    with_checkout do |root, ref|
      body = location_body(prepare(root, nil, {}, head: ref))
      assert_includes body, 'settings not read'
      assert_includes body, 'rerun description with --ref'
      assert_locations_withheld(body)
    end
  end

  def test_failed_settings_load_remains_publishable_without_evidence_and_withholds_locations
    with_checkout do |root, ref|
      body = location_body(prepare(root, 'missing-policy-ref', {}, head: ref))
      assert_includes body, 'settings unavailable'
      assert_includes body, 'fix seam check --ref'
      assert_locations_withheld(body)
      refute_includes body, 'missing-policy-ref'
    end
  end

  def test_missing_location_field_cannot_authorize_publication
    settings = Shaka::PublicationSettings.new(current: {})
    assert_locations_withheld(location_body(settings))
    refute_predicate settings, :include_locations?
  end

  def test_required_settings_load_still_refuses_failure
    with_checkout do |root, _ref|
      assert_raises(Shaka::Error) do
        Shaka::PublicationSettings.current_settings(root:, ref: 'missing-policy-ref',
                                                    repository: 'shakacode/shaka', required: true)
      end
    end
  end

  private

  def location_body(settings, thread: 'https://private.example/session')
    wip = Shaka::WipDetails::FIELDS.keys.to_h { |key| [key, 'UNKNOWN'] }
    wip['workspace'] = '/private/customer/project'
    wip['thread'] = thread
    Shaka::WipDetails.new(wip, location_redaction: settings.location_redaction).detail.fetch('body')
  end

  def assert_locations_withheld(body)
    refute_includes body, '/private/customer/project'
    refute_includes body, 'https://private.example/session'
  end

  def prepare(root, ref, options, head: ref)
    pull = { 'changed_files' => 0, 'head' => { 'sha' => head }, 'base' => { 'sha' => ref } }
    Shaka::PublicationSettings.prepare(root:, ref:, pull:,
                                       options: options.merge(root:), github: empty_diff)
  end

  def empty_diff
    Object.new.tap do |github|
      def github.repository = 'shakacode/shaka'
      def github.number = 1
      def github.api_list(_path) = []
    end
  end
end
