# frozen_string_literal: true

module Shaka
  # Links a commit to GitHub only when GitHub has it. A round reviewed before a rebase names a
  # commit that was never pushed, and a link to it would open a 404 page.
  class LocalReviewLinks
    def initialize(repository, published = nil)
      @repository = repository
      @published = published
      @known = {}
    end

    # Code spans are never auto-linked, so a commit needs an explicit link to be clickable.
    def commit(sha)
      code = "`#{sha[0, 7]}`"
      return code unless @repository
      return "#{code} (not on GitHub)" unless on_github?(sha)

      "[#{code}](https://github.com/#{@repository}/commit/#{sha})"
    end

    def criteria(sha)
      code = "`#{sha[0, 7]}`"
      @repository ? "[#{code}](https://github.com/#{@repository}/blob/#{sha}/AGENTS.md)" : code
    end

    private

    def on_github?(sha)
      return true unless @published

      @known.fetch(sha) { @known[sha] = @published.call(sha) }
    end
  end

  # The lines under the summary table: what the loop cost, why it stopped, and what the prompt
  # column means.
  class LocalReviewSummary
    INSTRUCTIONS = 'https://github.com/shakacode/shaka/blob/main/skills/shaka/config/review-prompt.md'
    RULES = 'https://github.com/shakacode/shaka/blob/main/skills/shaka/lib/shaka/review_prompt.rb'
    NUMBER = /\A\d{1,3}(?:,\d{3})*\z|\A\d+\z/
    MONEY = /\A\$?(\d+(?:\.\d+)?)\z/

    def initialize(rounds) = @rounds = rounds

    def lines = [total, outcome, prompt]

    private

    def total
      "**Total:** #{@rounds.size} #{@rounds.size == 1 ? 'round' : 'rounds'} · #{tokens} · #{cost}"
    end

    def tokens
      counts = @rounds.map { |round| round.value('tokens').to_s }
      return 'tokens UNKNOWN' unless counts.all? { |count| count.match?(NUMBER) }

      "#{group(counts.sum { |count| count.delete(',').to_i })} tokens"
    end

    # A subscription session has no per-token bill, so its dollar figure is an API-equivalent estimate.
    def cost
      amounts = @rounds.map { |round| price(round)[MONEY, 1] }
      return 'cost UNKNOWN' if amounts.any?(&:nil?)

      label = @rounds.all? { |round| round.value('cost') } ? 'cost' : 'API-equivalent estimate'
      format('$%<sum>.2f %<label>s', sum: amounts.sum(&:to_f), label:)
    end

    def price(round) = (round.value('cost') || round.value('estimate')).to_s

    def outcome
      last = @rounds.last
      return "**Outcome:** the loop ended clean: round #{@rounds.size} found nothing." if last.findings.empty?

      kinds = LocalReviewFinding::CLASSES.filter_map do |kind|
        count = last.findings.count { |finding| finding.kind == kind }
        "#{count} #{kind}" if count.positive?
      end
      "**Outcome:** #{reason(last)} Round #{@rounds.size}'s findings are documented, not fixed " \
        "(#{kinds.join(', ')})."
    end

    # A documented defect is the author's decision to leave it, so the comment says so plainly.
    def reason(last)
      defects = last.findings.count { |finding| finding.kind == 'defect' }
      return 'the loop ended with nothing left to fix.' if defects.zero?

      "the loop stopped with #{defects} unfixed #{defects == 1 ? 'defect' : 'defects'} left for the maintainer."
    end

    def prompt
      "**Prompt:** `Shaka default` is Shaka's [review instructions](#{INSTRUCTIONS}) plus its " \
        "[fixed rules](#{RULES}); a `review.prompt_file` entry names the repository file used instead. " \
        '`criteria SHA` means the reviewer also received the trusted `AGENTS.md` from that commit.'
    end

    def group(number) = number.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
  end
end
