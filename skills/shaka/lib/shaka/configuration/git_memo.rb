# frozen_string_literal: true

module Shaka
  module Configuration
    # Remembers Git answers that cannot change while one CLI process runs, because settings
    # resolution repeats them several times per command. Callers key each answer by what fixes
    # it: a full commit SHA, the worktree root, or the input of a pure check. Reads of HEAD,
    # the index, or the working tree never come here, so re-resolution still sees edits.
    # Only the CLI enables it; a failed lookup raises before anything is stored.
    module GitMemo
      SHA = /\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/

      @entries = nil

      class << self
        def enable = (@entries = {})
        def disable = (@entries = nil)

        def fetch(key)
          return yield unless @entries

          @entries.fetch(key) { @entries[key] = yield }
        end

        # Remembers a commit lookup only when the ref is already a full SHA, never a branch name.
        def commit(key, ref, &)
          full_sha?(ref) ? fetch(key, &) : yield
        end

        # Remembers a Git capture at a full SHA once it succeeds, so a failure such as a timeout runs again.
        def capture(key, ref)
          return yield unless @entries && full_sha?(ref)
          return @entries[key] if @entries.key?(key)

          result = yield
          @entries[key] = result if result.last.success?
          result
        end

        private

        def full_sha?(ref) = ref.is_a?(String) && ref.match?(SHA)
      end
    end
  end
end
