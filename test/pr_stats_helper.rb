# frozen_string_literal: true

require_relative 'throughput_helper'
require 'shaka/pr_watch/stats_command'

# A merged pull request and trusted settings shared by the pr stats tests.
module PrStatsHelper
  include ThroughputHelper

  Seam = Struct.new(:merge, :review)
  SEAM = Seam.new({}, { 'ci_review_jobs' => [], 'ci_review_wait' => 'none' })

  private

  def unready_block = describe('$4.12', timeline: push_times, pull: head_pull)

  def merged_page
    { 'headRefOid' => HEAD, 'mergedAt' => MERGED.iso8601,
      'commits' => { 'nodes' => [{ 'commit' => gql(HEAD, PUSH.iso8601, []) }] } }
  end

  # Replaces GitHub and the trusted settings for one block, so run exercises its real argument handling.
  def with_stubs(github)
    swaps = { Shaka::GitHub => [:new, github], Shaka::PrWatch::StatsCommand => [:trusted_seam, SEAM] }
    originals = swaps.to_h { |owner, (name, _)| [owner, owner.method(name)] }
    swaps.each { |owner, (name, value)| owner.define_singleton_method(name) { |*| value } }
    yield
  ensure
    originals.each { |owner, original| owner.define_singleton_method(original.name, original) }
  end
end

# A pull request GitHub merged after its required check passed, with nothing recorded since publication.
class MergedFakeGitHub < ThroughputFakeGitHub
  def initialize(body, pull, times = [{ 'name' => 'validate', 'bucket' => 'pass',
                                        'completedAt' => ThroughputHelper::READY.iso8601 }])
    super
  end

  def snapshot = { 'headRefOid' => ThroughputHelper::HEAD, 'state' => 'MERGED', 'baseRefName' => 'main' }
  def required_checks = [{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]
  def configured_required_checks = []
  def checks = required_checks
end
