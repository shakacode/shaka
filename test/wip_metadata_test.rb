# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'handoff_helper'
require 'shaka/publication/publication'
require 'shaka/publication/publishing'
require 'shaka/publication/wip_metadata'

module WipMetadataFixture
  UUID = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
  LOCATOR = "codex://threads/#{UUID}".freeze
  WIP = { 'owner' => 'm5 · Codex desktop · k7q2', 'task' => 'shaka #906 collect WIP metadata',
          'thread' => LOCATOR, 'last_observed_activity' => '2026-10-27 03:40 UTC',
          'revision' => "feature @ #{'a' * 40}", 'workspace' => 'UNKNOWN',
          'unfinished_work' => 'none', 'stopped_because' => 'paused', 'merge_authority' => 'ask',
          'state' => 'in progress', 'next_action' => 'finish the metadata check' }.freeze
  IDENTITY = { 'agent' => 'Codex', 'provider' => 'OpenAI', 'model' => 'gpt-6.1-sol', 'effort' => 'medium' }.freeze
  PROVENANCE = { 'task_source' => 'issue', 'initial_prompt' => 'EXCLUDED',
                 'requested_model' => 'UNKNOWN', 'requested_effort' => 'UNKNOWN',
                 'recommended_model' => 'UNKNOWN', 'recommended_effort' => 'UNKNOWN',
                 'active_model' => 'UNKNOWN', 'active_effort' => 'UNKNOWN' }.freeze

  def codex_env = { 'CODEX_THREAD_ID' => UUID, 'SHAKA_MACHINE_ALIAS' => 'm5' }

  def render(wip, environment: {}, disclosure: nil, previous: nil, host_name: 'test-host')
    content = description(wip, disclosure)
    Shaka::Publication.description(content, nil, pull(previous), nil, nil, environment:, host_name:)
  end

  def description(wip, disclosure)
    content = { 'identity' => IDENTITY, 'summary' => 'Collect WIP metadata before publication.',
                'table' => { 'columns' => %w[Check Result], 'rows' => [%w[validate pass]] },
                'deployment' => 'none', 'steps_besides_merging' => 'none',
                'intent' => INTENT, 'verification' => VERIFICATION,
                'provenance' => PROVENANCE, 'usage' => HandoffFixtures::USAGE, 'details' => [], 'wip' => wip }
    disclosure ? content.merge('wip_disclosure' => disclosure) : content
  end

  def pull(body)
    return unless body

    { 'head' => { 'sha' => 'a' * 40, 'repo' => { 'full_name' => 'acme/widgets' } },
      'base' => { 'repo' => { 'full_name' => 'acme/widgets' } }, 'body' => body }
  end

  def wrapped(body) = "#{Shaka::Publishing::OPEN_MARK}\n#{body}#{Shaka::Publishing::CLOSE_MARK}"

  def marker(dispositions) = Shaka::WipMetadata.marker(dispositions)
end

class WipMetadataTest < Minitest::Test
  include WipMetadataFixture

  def test_available_codex_metadata_is_published_and_recorded
    rendered = render(WIP, environment: codex_env)

    assert_includes rendered, '| Owner | m5 · Codex desktop · k7q2 |'
    assert_includes rendered, "| Chat link | #{LOCATOR} |"
    assert_includes rendered, 'Collection: alias available; host available; tag available; thread available.'
    assert_includes rendered, marker('alias' => 'available', 'host' => 'available', 'tag' => 'available',
                                     'thread' => 'available')
  end

  def test_unknown_is_refused_when_the_alias_or_thread_was_available
    error = assert_raises(Shaka::Error) { render(WIP.merge('owner' => 'UNKNOWN', 'thread' => 'UNKNOWN'), environment: codex_env) }

    assert_includes error.message, 'machine alias was available but was not collected'
    refute_includes error.message, UUID
  end

  def test_an_uncollected_chat_link_does_not_echo_the_thread_id
    error = assert_raises(Shaka::Error) { render(WIP.merge('thread' => 'UNKNOWN'), environment: codex_env) }

    assert_includes error.message, 'chat link was available'
    refute_includes error.message, UUID
    refute_includes error.message, LOCATOR
  end

  def test_missing_invalid_and_withheld_values_stay_unknown_without_the_raw_value
    missing = render(WIP.merge('owner' => 'UNKNOWN', 'thread' => 'UNKNOWN'))
    assert_includes missing, 'Collection: alias unavailable; host unavailable; tag unavailable; thread unavailable.'

    invalid_id = 'session-secret-value'
    invalid = render(WIP.merge('thread' => 'UNKNOWN'), environment: { 'CODEX_THREAD_ID' => invalid_id })
    assert_includes invalid, 'thread invalid'
    refute_includes invalid, invalid_id

    withheld = render(WIP.merge('thread' => 'UNKNOWN'), environment: codex_env, disclosure: { 'thread' => 'withheld' })
    assert_includes withheld, 'thread withheld'
    refute_includes withheld, UUID
  end

  def test_a_machine_name_alias_is_withheld_and_omitted_from_diagnostics
    environment = { 'SHAKA_MACHINE_ALIAS' => 'build-host', 'HOST' => 'build-host.local' }
    rendered = render(WIP.merge('owner' => 'UNKNOWN'), environment:, host_name: 'build-host.local')

    assert_includes rendered, 'alias withheld'
    refute_includes rendered, 'build-host'
    error = assert_raises(Shaka::Error) do
      render(WIP.merge('owner' => 'build-host · Codex desktop · k7q2'), environment:, host_name: 'build-host.local')
    end
    assert_includes error.message, "this machine's own name"
    refute_includes error.message, 'build-host'
  end

  def test_a_share_link_is_refused_without_repeating_the_url
    secret = 'https://chatgpt.com/share/super-secret-token'
    error = assert_raises(Shaka::Error) { render(WIP.merge('thread' => secret)) }

    assert_includes error.message, 'conversation content'
    refute_includes error.message, secret
    refute_includes error.message, 'super-secret-token'
  end

  def test_cursor_has_a_host_but_no_supported_chat_locator
    environment = { 'CURSOR_CONVERSATION_ID' => 'cursor-session', 'SHAKA_MACHINE_ALIAS' => 'm5' }
    rendered = render(WIP.merge('owner' => 'm5 · Cursor · k7q2', 'thread' => 'UNKNOWN'), environment:)

    assert_includes rendered, 'host available'
    assert_includes rendered, 'thread unavailable'
    unknown_host = WIP.merge('owner' => 'm5 · UNKNOWN · k7q2', 'thread' => 'UNKNOWN')
    error = assert_raises(Shaka::Error) { render(unknown_host, environment:) }
    assert_includes error.message, 'host was available (Cursor)'
    refute_includes error.message, 'cursor-session'
  end

  def test_an_ambiguous_host_does_not_invent_a_codex_locator
    environment = codex_env.merge('CURSOR_CONVERSATION_ID' => 'cursor-session')
    rendered = render(WIP.merge('thread' => 'UNKNOWN'), environment:)

    assert_includes rendered, 'host unavailable'
    assert_includes rendered, 'thread unavailable'
    refute_includes rendered, UUID
  end

  def test_a_previously_collected_tag_cannot_become_unknown_unless_withheld
    previous = wrapped(render(WIP))
    error = assert_raises(Shaka::Error) do
      render(WIP.merge('owner' => 'm5 · Codex desktop · UNKNOWN'), previous:)
    end
    assert_includes error.message, 'owner tag was collected earlier'
    refute_includes error.message, 'k7q2'

    withheld = { 'tag' => 'withheld' }
    rendered = render(WIP.merge('owner' => 'm5 · Codex desktop · UNKNOWN'), previous:, disclosure: withheld)
    assert_includes rendered, 'tag withheld'
    refute_includes rendered, 'k7q2'
  end

  def test_a_published_value_that_was_withheld_is_flagged_without_the_value
    rendered = render(WIP.merge('thread' => 'UNKNOWN'), environment: codex_env, disclosure: { 'thread' => 'withheld' })
    note = rendered[%r{<details>\n<summary>WIP Details</summary>\n\n(.*?)\n\n</details>}m, 1]
    edited = note.sub('| Chat link | UNKNOWN |', '| Chat link | https://chatgpt.com/share/SECRET |')
    secret = 'https://chatgpt.com/share/SECRET'
    problem = Shaka::WipMetadata.handoff_problem(edited, owner: 'm5 · Codex desktop · k7q2', thread: secret)

    assert_includes problem, 'conversation content'
    refute_includes problem, 'SECRET'
    refute_includes problem, UUID
  end

  def test_disclosure_rejects_unknown_fields_and_other_choices
    error = assert_raises(Shaka::Error) { render(WIP, disclosure: { 'mood' => 'withheld' }) }
    assert_includes error.message, 'unknown fields: mood'
    error = assert_raises(Shaka::Error) { render(WIP, disclosure: { 'thread' => 'publish' }) }
    assert_includes error.message, 'must be withheld'
    refute_includes error.message, 'publish'
  end
end

# The marker carries the collection record that handoff reads later.
class WipMetadataMarkerTest < Minitest::Test
  include WipMetadataFixture

  # A hand edit can drop the marker's closing delimiter or split it across lines.
  def test_a_truncated_or_split_marker_is_unreadable
    dispositions = Shaka::WipMetadata::FIELDS.to_h { [it, 'available'] }
    split = Shaka::WipMetadata.marker(dispositions).sub('{', "{\n")
    truncated = Shaka::WipMetadata.marker(dispositions).delete_suffix(' -->')

    [truncated, split].each do |note|
      problem = Shaka::WipMetadata.handoff_problem(note, owner: 'm5 · Codex desktop · k7q2', thread: LOCATOR)
      assert_equal Shaka::WipMetadata::UNREADABLE, problem
    end
  end
end
