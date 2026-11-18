# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/companions/pack'

# The pack file schema refuses entries the resolver could not apply safely.
class CompanionsPackTest < Minitest::Test
  POINT = 'ui-verification#ui-changes'
  NON_STRING_KEY = "version: 1\npack: team\n" \
                   "skills: { check: { path: a, points: { a#b: { mode: use, reason: r, 0: x } } } }\n"

  DUPLICATE_FLAG = "version: 1\npack: team\nskills:\n  check:\n    path: a\n    fans_out: true\n    fans_out: false\n"

  def test_a_valid_pack_records_only_stated_flags
    skill = parse(skills: { 'check' => entry('setup' => true,
                                             'points' => { POINT => setting('suggest') }) }).skills.first

    assert_equal({ 'setup' => true }, skill.flags)
    assert_equal ['suggest', 'Checks coverage'], skill.points.fetch(POINT)
    assert_equal '.agents/skills/check', skill.path
  end

  def test_a_pack_wide_setting_may_only_decline
    assert_refused('may only decline', skills: { 'check' => entry('points' => { '*' => setting('suggest') }) })
    assert parse(skills: { 'check' => entry('points' => { '*' => setting('decline') }) })
  end

  def test_every_skill_needs_a_relative_path_inside_the_repository
    assert_refused('must name a relative directory', skills: { 'check' => { 'points' => {} } })
    assert_refused('must name a relative directory', skills: { 'check' => entry('path' => '../x') })
    assert_refused('must name a relative directory', skills: { 'check' => entry('path' => '/abs') })
  end

  def test_unknown_keys_and_bad_values_are_refused
    assert_refused('unknown key source', source: 'https://example.com')
    assert_refused('has unknown key match', skills: { 'check' => entry('match' => {}) })
    assert_refused('must be true or false', skills: { 'check' => entry('fans_out' => 'yes') })
    assert_refused('must set mode and reason',
                   skills: { 'check' => entry('points' => { POINT => { 'mode' => 'use' } }) })
    assert_refused('must set mode and reason', text: NON_STRING_KEY)
    assert_refused('not valid YAML', text: "skills: [\n")
    assert_refused('duplicate key: fans_out', text: DUPLICATE_FLAG)
  end

  private

  def entry(extra = {}) = { 'path' => '.agents/skills/check' }.merge(extra)

  def setting(mode) = { 'mode' => mode, 'reason' => 'Checks coverage' }

  def parse(overrides = {})
    data = { 'version' => 1, 'pack' => 'team' }
    overrides.each { |key, value| data[key.to_s] = value }
    Shaka::Companions::Pack.parse(overrides.fetch(:text, YAML.dump(data)), label: 'team.yml')
  end

  def assert_refused(message, overrides = {})
    error = assert_raises(Shaka::Error) { parse(overrides) }
    assert_includes error.message, message
  end
end
