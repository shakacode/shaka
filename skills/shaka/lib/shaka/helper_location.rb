# frozen_string_literal: true

require_relative 'error'
require_relative 'local_review/executable'

module Shaka
  # A helper inside the checkout it reads is candidate code: a branch change can replace it.
  module HelperLocation
    SKILL_DIRECTORY = File.expand_path('../..', __dir__)

    def self.refuse_inside!(root)
      skill = File.realpath(SKILL_DIRECTORY)
      checkout = File.realpath(root)
      return unless LocalReviewExecutable.candidate_owned?(skill, checkout)

      raise Error, "The shaka skill at #{skill} resolves inside the checkout #{checkout}; " \
                   'run the copy installed outside every candidate checkout'
    rescue SystemCallError => e
      raise Error, "Cannot resolve the checkout #{root}: #{e.message}"
    end
  end
end
