# frozen_string_literal: true

require_relative 'handoff_helper'

class HandoffOwnerTest < Minitest::Test
  include HandoffHarness

  def test_live_owner_missing_the_machine_is_owed_even_with_a_current_revision
    edited = description.sub('| Owner | m5 · Claude Code · k7q2 |', '| Owner | Codex · 01a109ad |')
    result = handoff(body: edited)

    assert(result.fetch('owed').any? { |item| item.include?('machine alias · host · owner tag') })
    assert_equal 2, Shaka::Handoff.exit_status(result)
  end

  def test_replacing_a_collected_owner_with_unknown_is_owed
    edited = description.sub('| Owner | m5 · Claude Code · k7q2 |', '| Owner | UNKNOWN |')
    owed = handoff(body: edited).fetch('owed')

    assert(owed.any? { |item| item.include?('owner tag was available but is UNKNOWN') })
    refute(owed.any? { |item| item.include?('k7q2') })
  end

  def test_unknown_owner_with_unavailable_metadata_remains_recoverable
    assert_empty handoff(body: description(WIP.merge('owner' => 'UNKNOWN'))).fetch('owed')
  end

  def test_a_note_without_collection_evidence_is_owed
    body = description.sub(/<!-- shaka:wip-metadata .* -->/, '')
    owed = handoff(body:).fetch('owed')

    assert(owed.any? { |item| item.include?('collection evidence is missing') })
  end
end
