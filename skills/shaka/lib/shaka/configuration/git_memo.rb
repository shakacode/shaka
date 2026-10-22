# frozen_string_literal: true

module Shaka
  module Configuration
    # Remembers Git answers that cannot change while one CLI process runs, because settings
    # resolution repeats them several times per command. Callers key each answer by what fixes
    # it: a full commit SHA, the worktree root, or the input of a pure check. Reads of HEAD,
    # the index, or the working tree never come here, so re-resolution still sees edits.
    # Only the CLI enables it; a failed lookup raises or is refused by `keep` before anything is stored.
    module GitMemo
      SHA = /\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/
      ALWAYS = ->(_value) { true }

      @entries = nil

      class << self
        def enable = (@entries = {})
        def disable = (@entries = nil)

        def fetch(key, keep: ALWAYS)
          return yield unless @entries
          return @entries[key] if @entries.key?(key)

          value = yield
          @entries[key] = value if keep.call(value)
          value
        end

        # Remembers a commit lookup only when the ref is already a full SHA, never a branch name.
        def commit(key, ref, keep: ALWAYS, &)
          full_sha?(ref) ? fetch(key, keep:, &) : yield
        end

        # Remembers a Git capture at a full SHA once it succeeds, so a failure such as a timeout runs again.
        def capture(key, ref, &) = commit(key, ref, keep: ->(result) { result.last.success? }, &)

        private

        def full_sha?(ref) = ref.is_a?(String) && ref.match?(SHA)
      end
    end
  end
end
