# frozen_string_literal: true

require_relative '../executable_file'

module Shaka
  # Identifies paths owned by the candidate checkout.
  module LocalReviewExecutable
    # Windows paths ignore case and accept either separator, so there C:\Repo\bin and c:/repo name
    # the same checkout, and a candidate executable must not pass as external.
    def self.candidate_owned?(target, root, windows: ExecutableFile.windows?)
      target, root = [target, root].map { |path| path.tr('\\', '/').downcase.chomp('/') } if windows
      target == root || target.start_with?("#{root}/")
    end
  end
end
