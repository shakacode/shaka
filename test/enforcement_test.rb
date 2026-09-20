# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'
require 'shaka/enforcement_config'
require 'shaka/enforcement_coverage'

class EnforcementConfigTest < Minitest::Test
  def test_the_packaged_audit_classifies_every_rule_the_packaged_workflow_states
    rules = Shaka::EnforcementConfig.load.fetch('rules')

    refute_empty rules
    assert_equal rules.length, rules.map { |rule| rule.fetch('id') }.uniq.length
    rules.each { |rule| assert_match Shaka::EnforcementCoverage::MARKER, rule.fetch('quote') }
  end

  def test_every_audited_rule_names_what_backs_it
    Shaka::EnforcementConfig.load.fetch('rules').each do |rule|
      backing = Shaka::EnforcementConfig::BACKED.include?(rule.fetch('enforced_by')) ? 'detector' : 'note'

      refute_empty rule.fetch(backing).strip, "#{rule.fetch('id')} states no #{backing}"
    end
  end

  # The audit's whole value is that it cannot quietly go stale, so these are the two ways it
  # could: the workflow drops the sentence, or the workflow gains a rule nobody classified.
  def test_rejects_a_quote_the_workflow_no_longer_contains
    audit = packaged_audit
    audit.fetch('rules').first['quote'] = 'never do a thing this workflow does not mention'

    error = assert_raises(Shaka::Error) { load_audit(audit) }

    assert_includes error.message, 'quotes text the'
  end

  def test_rejects_a_workflow_rule_no_entry_classifies
    ['Never leave a rule unclassified.', 'Classify a rule only when it is audited.',
     'A new rule must be audited.', 'Do not skip a rule.'].each do |added|
      workflow = Shaka::WorkflowConfig.load
      workflow['code_quality'] += " #{added}"

      error = assert_raises(Shaka::Error) { Shaka::EnforcementConfig.load(workflow:) }

      assert_includes error.message, 'classifies no rule for code_quality'
    end
  end

  def test_rejects_an_entry_that_quotes_no_rule
    audit = packaged_audit
    audit.fetch('rules').first['quote'] = 'Read the task through an available connection'

    error = assert_raises(Shaka::Error) { load_audit(audit) }

    assert_includes error.message, 'states no rule'
  end

  def test_rejects_an_ambiguous_quote
    workflow = Shaka::WorkflowConfig.load
    workflow['always'] += ' Never push to `main`.'

    error = assert_raises(Shaka::Error) { Shaka::EnforcementConfig.load(workflow:) }

    assert_includes error.message, 'appears twice'
  end

  def test_requires_a_detector_from_a_rule_claiming_code_backs_it
    message = mutated_message { |rules| rules.find { |rule| rule['enforced_by'] == 'code' }.delete('detector') }

    assert_includes message, 'detector must be non-empty'
  end

  def test_refuses_a_detector_on_an_agent_enforced_rule
    message = mutated_message do |rules|
      rules.find { |rule| rule['enforced_by'] == 'agent' }['detector'] = 'wishful thinking'
    end

    assert_includes message, 'agent-enforced, so it takes no detector'
  end

  def test_rejects_an_unknown_enforcer_a_duplicate_id_and_an_unknown_key
    assert_includes mutated_message { |rules| rules.first['enforced_by'] = 'vibes' }, 'enforced_by must be'
    assert_includes mutated_message { |rules| rules.push(rules.first.dup) }, 'duplicate rule id'
    assert_includes mutated_message { |rules| rules.first['surprise'] = true }, 'unknown rule'
  end

  def test_rejects_duplicate_keys_and_an_unknown_top_level_key
    source = YAML.dump(packaged_audit).sub("version: 1\n", "version: 1\nversion: 1\n")
    assert_includes assert_raises(Shaka::Error) { load_source(source) }.message, 'duplicate key'

    audit = packaged_audit.merge('surprise' => true)
    assert_includes assert_raises(Shaka::Error) { load_audit(audit) }.message, 'unknown enforcement key'
  end

  private

  def packaged_audit
    YAML.safe_load(File.read(Shaka::EnforcementConfig::PATH, encoding: 'UTF-8'))
  end

  def load_audit(audit) = load_source(YAML.dump(audit))

  def load_source(source) = Shaka::EnforcementConfig.load(source:)

  def mutated_message
    audit = packaged_audit
    yield audit.fetch('rules')
    assert_raises(Shaka::Error) { load_audit(audit) }.message
  end
end

class EnforcementCommandTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  RULES = Shaka::EnforcementConfig.load.fetch('rules')

  def test_reports_every_audited_rule_under_its_workflow_section
    output, status = report

    assert status.success?, output
    assert_equal RULES.map { |rule| rule['phase'] }.uniq.length, output.scan(/^## /).size
    assert_equal RULES.length, output.scan(/^\| .* \| (?:code|reported|github|agent) \| /).size
  end

  def test_counts_how_many_rules_nothing_but_the_agent_enforces
    output, status = report
    alone = RULES.count { |rule| rule['enforced_by'] == 'agent' }

    assert status.success?, output
    assert_includes output, "#{RULES.length} audited rules"
    assert_includes output, "#{alone} enforced by nothing but the agent."
  end

  # The audit claims less than "every imperative rule", and it claims nothing about live
  # GitHub settings. Both limits belong in the report a maintainer reads, not just here.
  def test_states_what_it_does_not_cover
    output, status = report

    assert status.success?, output
    assert_includes output, 'never, must, do not, or only when'
    assert_includes output, 'outside it'
    assert_includes output, 'nothing here confirms that a GitHub setting is still active'
  end

  # A command that only reports a violation must not read as one that refuses it.
  def test_separates_a_reported_violation_from_a_refused_one
    output, status = report

    assert status.success?, output
    assert_includes output, '`reported` — a command surfaces the violation; the agent can still proceed.'
    assert_includes output, '| Do not open a second PR. | reported |'
  end

  def test_names_the_agent_as_the_only_enforcement_where_nothing_checks
    output, status = report

    assert status.success?, output
    assert_includes output, '`agent` — nothing checks it'
    assert_includes output, '| Never defer always-on required, security, or trust checks. | agent |'
  end

  def test_rejects_arguments
    output, status = Open3.capture2e(COMMAND, 'enforcement', 'candidate.yml')

    refute status.success?
    assert_includes output, 'Usage: shaka enforcement'
  end

  private

  # The report is UTF-8 prose; a POSIX locale would otherwise hand the test binary bytes.
  def report
    output, status = Open3.capture2e(COMMAND, 'enforcement')
    [output.force_encoding(Encoding::UTF_8), status]
  end
end
