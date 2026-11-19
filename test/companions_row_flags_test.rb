# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/companions/resolver'

# A row carries fan-out and explicit-only facts whatever its mode, so a `suggest` row keeps them too.
class CompanionsRowFlagsTest < Minitest::Test
  POINT = 'ui-verification#ui-changes'
  PATH = '/home/me/skills/coverage'

  def test_a_suggested_skill_that_fans_out_says_so
    fans_out = entry('repository', 'suggest', flags: { 'fans_out' => true })

    row = first_row(fans_out)

    assert_equal ['suggest', true], [row.mode, row.fans_out]
    refute first_row(entry('repository', 'suggest')).fans_out
  end

  def test_a_suggested_explicit_only_skill_says_so
    flagged = entry('repository', 'suggest', flags: { 'explicit_only' => true })
    person_only = entry('repository', 'suggest', front: true)

    rows = [flagged, person_only].map { |each| first_row(each) }

    assert_equal([['suggest', 'repository entry'], ['suggest', 'repository entry']], rows.map { [it.mode, it.basis] })
    assert_equal [true, true], rows.map(&:explicit_only)
    refute first_row(entry('repository', 'suggest')).explicit_only
  end

  private

  def first_row(entry) = Shaka::Companions::Resolver.new([entry]).call(POINT).first

  def entry(layer, mode, flags: {}, front: false, **where)
    candidate = where.fetch(:candidate, false)
    pack = where.fetch(:pack, 'perf')
    point = where.fetch(:point, POINT)
    skill = Shaka::Companions::Pack::Skill.new(name: 'coverage', flags:, path: nil,
                                               points: { point => [mode, "#{layer} reason"] })
    Shaka::Companions::Resolver::Entry.new(layer:, pack:, skill:, identity: PATH, installed: true, location: PATH,
                                           skill_file: nil, revision: 'abc', explicit_front: front,
                                           candidate_only: candidate)
  end
end
