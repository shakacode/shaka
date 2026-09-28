# frozen_string_literal: true

require_relative 'attention'
require_relative 'error'
require_relative 'publication_sections'

module Shaka
  # Keeps awaiting-answer aligned with the description's decisions list.
  class DecisionLabels
    def self.guard(github, content, existing_body = nil)
      decisions = list(content)
      if decisions.nil? && asks_for_decisions?(existing_body)
        raise Error, 'Pass decisions or an empty list; the pull request already asks for decisions.'
      end
      return if decisions.nil? || decisions.empty?
      raise Error, 'Pull request is not open.' unless github.snapshot['state'] == 'OPEN'

      Attention.new(github).refuse_merge_wait
    end

    def self.sync(github, content)
      decisions = list(content)
      return if decisions.nil?

      attention = Attention.new(github)
      decisions.empty? ? attention.release_answer : attention.call(state: 'answer', refuse_merge: true)
    end

    def self.asks_for_decisions?(body)
      fenced = false
      body.to_s.each_line.any? do |line|
        fenced = !fenced if line.lstrip.start_with?('```', '~~~')
        next false if fenced

        line.strip == PublicationSections::MARKER
      end
    end

    def self.list(content)
      return unless content.key?('decisions')

      decisions = content['decisions']
      raise Error, 'Publication decisions must be a list.' unless decisions.is_a?(Array)

      decisions
    end

    private_class_method :asks_for_decisions?, :list
  end
end
