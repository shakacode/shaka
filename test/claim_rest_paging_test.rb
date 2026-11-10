# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'claim_helpers'
require_relative 'claim_rest_helpers'

# REST pages by offset, unlike `gh pr list`, so claim reads every page and notices a list that moved.
class ClaimRestPagingTest < Minitest::Test
  include ClaimHelpers
  include ClaimRestHelpers

  def test_an_owning_pull_request_on_a_later_page_is_found
    result = claim_over_rest('392', pulls: [unrelated_page, [PULL]])

    assert_equal([402], result.fetch('pull_requests').map { |pr| pr.fetch('number') })
  end

  def test_a_list_that_changes_between_paged_reads_is_an_error
    runner = changing_runner([[unrelated_page, [PULL]], [unrelated_page.drop(1), [PULL]]])
    error = assert_raises(Shaka::Error) { Shaka::Claim.new(query: '392', root: Dir.pwd, runner:).result }

    assert_includes error.message, 'inventory changed'
  end

  private

  # Each read of the first page starts the next listing in `reads`.
  def changing_runner(reads)
    inner = rest_runner(pulls: [])
    lambda do |argv, **|
      inner = rest_runner(pulls: reads.shift) if argv.last.to_s.end_with?('pulls?per_page=100&page=1')
      inner.call(argv)
    end
  end
end
