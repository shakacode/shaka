# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/companions/resolver'

# One row per layering and trust rule in ADR 0009 decisions 2, 3, and 6.
class CompanionsResolverTest < Minitest::Test
  POINT = 'ui-verification#ui-changes'
  PATH = '/home/me/.claude/skills/coverage'

  CASES = [
    ['packaged suggest stays suggest', [%w[packaged suggest]], {}, 'suggest', 'packaged entry'],
    ['packaged use acts as suggest until its pack is on', [%w[packaged use]], {}, 'suggest', 'not turned on'],
    ['packaged use applies once its pack is on', [%w[packaged use]], { enabled: ['perf'] }, 'use', 'packaged entry'],
    ['personal use acts as suggest', [%w[personal use]], { enabled: ['perf'] }, 'suggest', 'personal'],
    ['repository use needs no pack switch or study', [%w[repository use]], {}, 'use', 'repository entry'],
    ['fans-out stays suggest under a repository use',
     [['packaged', 'suggest', { 'fans_out' => true }], ['repository', 'use', { 'fans_out' => false }]],
     {}, 'suggest', 'fans out'],
    ['explicit-only flag caps use', [['repository', 'use', { 'explicit_only' => true }]], {}, 'suggest', 'explicit'],
    ['explicit front matter caps use even with the flag cleared',
     [['packaged', 'suggest', { 'explicit_only' => true }], ['repository', 'use', { 'explicit_only' => false }]],
     { front: true }, 'suggest', 'explicit'],
    ['the repository clears a packaged explicit flag when front matter allows it',
     [['packaged', 'suggest', { 'explicit_only' => true }], ['repository', 'use', { 'explicit_only' => false }]],
     {}, 'use', 'repository entry'],
    ['a personal entry cannot clear a packaged flag',
     [['packaged', 'use', { 'setup' => true }], ['personal', 'suggest', { 'setup' => false }]],
     { enabled: ['perf'] }, 'suggest', 'setup'],
    ['the repository may clear a setup flag',
     [['packaged', 'suggest', { 'setup' => true }], ['repository', 'use', { 'setup' => false }]],
     {}, 'use', 'repository entry'],
    ['any repository entry that sets a flag wins, in either order',
     [['repository', 'use', { 'explicit_only' => false }], ['repository', 'use', { 'explicit_only' => true }]],
     {}, 'suggest', 'explicit'],
    ['any repository entry that sets a flag wins, reversed',
     [['repository', 'use', { 'explicit_only' => true }], ['repository', 'use', { 'explicit_only' => false }]],
     {}, 'suggest', 'explicit'],
    ['unread front matter counts as explicit-only', [%w[repository use]], { front: nil }, 'suggest', 'explicit'],
    ['a personal decline beats a repository use', [%w[repository use], %w[personal decline]], {}, 'decline',
     'personal'],
    ['a packaged decline applies without a repository entry', [%w[packaged decline], %w[personal suggest]], {},
     'decline', 'packaged'],
    ['the repository may lift a packaged decline', [%w[packaged decline], %w[repository suggest]], {}, 'suggest',
     'repository entry'],
    ['the strictest packaged entry wins for one installed path', [%w[packaged suggest], %w[packaged decline]], {},
     'decline', 'packaged'],
    ['no trusted ref drops repository entries', [%w[packaged suggest], %w[repository use]], { trusted: false },
     'suggest', 'packaged entry'],
    ['no trusted ref still applies the machine layer', [%w[personal decline]], { trusted: false }, 'decline',
     'personal'],
    ['a candidate-only project skill is declined', [%w[repository use]], { candidate: true }, 'decline', 'candidate']
  ].freeze

  CASES.each_with_index do |(name, layers, options, mode, basis), index|
    define_method("test_#{index}_#{name.tr(' -', '__')}") do
      row = resolve(layers, **options)

      assert_equal mode, row.mode, name
      assert_includes row.basis, basis, name
    end
  end

  def test_declines_match_by_installed_path_not_pack_name
    entries = [entry('packaged', 'decline', pack: 'orchestrators'), entry('personal', 'suggest', pack: 'mine')]

    rows = Shaka::Companions::Resolver.new(entries).call(POINT)

    assert_equal ['decline'], rows.map(&:mode)
  end

  def test_a_pack_wide_decline_covers_every_point
    any = entry('packaged', 'decline', point: '*')

    rows = Shaka::Companions::Resolver.new([any]).call('delivery#when-a-task-needs-several-prs')

    assert_equal ['decline'], rows.map(&:mode)
  end

  def test_a_use_entry_for_a_missing_skill_says_it_is_not_installed
    missing = entry('repository', 'use').with(installed: false, explicit_front: nil)

    row = Shaka::Companions::Resolver.new([missing]).call(POINT).first

    assert_equal ['suggest', 'it is not installed'], [row.mode, row.basis]
  end

  def test_a_skill_without_this_point_is_not_listed
    assert_empty Shaka::Companions::Resolver.new([entry('packaged', 'suggest')]).call('delivery#other')
  end

  private

  def resolve(layers, enabled: [], trusted: true, front: false, candidate: false)
    entries = layers.map { |layer, mode, flags| entry(layer, mode, flags: flags || {}, front:, candidate:) }
    rows = Shaka::Companions::Resolver.new(entries, enabled_packs: enabled, trusted:).call(POINT)
    assert_equal 1, rows.length
    rows.first
  end

  def entry(layer, mode, flags: {}, front: false, **where)
    candidate = where.fetch(:candidate, false)
    pack = where.fetch(:pack, 'perf')
    point = where.fetch(:point, POINT)
    skill = Shaka::Companions::Pack::Skill.new(name: 'coverage', flags:, study: nil, path: nil,
                                               points: { point => [mode, "#{layer} reason"] })
    Shaka::Companions::Resolver::Entry.new(layer:, pack:, skill:, identity: PATH, installed: true, location: PATH,
                                           revision: 'abc', explicit_front: front, candidate_only: candidate)
  end
end
