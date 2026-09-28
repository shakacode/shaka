# frozen_string_literal: true

require_relative 'attention'
require_relative 'error'

module Shaka
  # Keeps awaiting-answer aligned with the description's decisions list.
  class DecisionLabels
    def self.sync(github, content)
      decisions = list(content)
      return if decisions.nil?

      attention = Attention.new(github)
      decisions.empty? ? attention.release_answer : attention.call(state: 'answer', refuse_merge: true)
    end

    def self.list(content)
      return unless content.key?('decisions')

      decisions = content['decisions']
      raise Error, 'Publication decisions must be a list.' unless decisions.is_a?(Array)

      decisions
    end

    private_class_method :list
  end
end
