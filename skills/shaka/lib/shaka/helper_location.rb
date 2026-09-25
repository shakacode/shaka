# frozen_string_literal: true

require 'open3'
require_relative 'error'
require_relative 'local_review/executable'

module Shaka
  # A helper inside the checkout it reads is candidate code: a branch change can replace it.
  module HelperLocation
    SKILL_DIRECTORY = File.expand_path('../..', __dir__)

    def self.refuse_inside!(root)
      skill = File.realpath(SKILL_DIRECTORY)
      checkout = checkout_root(root)
      return unless LocalReviewExecutable.candidate_owned?(skill, checkout)

      raise Error, "The shaka skill at #{skill} resolves inside the checkout #{checkout}; " \
                   'run the copy installed outside every candidate checkout'
    rescue SystemCallError => e
      raise Error, "Cannot resolve the checkout #{root}: #{e.message}"
    end

    # Git reads the enclosing repository from any directory below it, so a subdirectory root
    # must be compared as the whole checkout.
    def self.checkout_root(root)
      directory = File.realpath(root)
      toplevel, _error, status = Open3.capture3('git', '-C', directory, 'rev-parse', '--show-toplevel')
      status.success? ? File.realpath(toplevel.chomp) : directory
    end
    private_class_method :checkout_root
  end
end
