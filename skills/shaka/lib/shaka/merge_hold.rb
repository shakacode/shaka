# frozen_string_literal: true

require_relative 'defaults'
require_relative 'error'

module Shaka
  # The labels a maintainer puts on a PR to stop it merging. Nothing confirms past one: the
  # maintainer removes the label, so neither Auto nor an instruction to merge can land a held PR.
  class MergeHold
    SETTING = 'merge.hold_labels'
    DEFAULT = Defaults.fetch('merge', 'hold_labels')

    # seam is the trusted RepositoryConfig; without one the shipped labels apply.
    def self.from(seam) = new(seam&.merge&.fetch('hold_labels', nil) || DEFAULT)

    attr_reader :labels

    def initialize(labels = DEFAULT)
      @labels = labels
    end

    # names are the label names the PR carries; returns the first hold label among them, or nil.
    def label(names) = names.find { |name| @labels.any? { |hold| hold.casecmp?(name) } }

    # pull is a GitHub snapshot carrying `labels { totalCount nodes { name } }`.
    def verify!(pull)
      held = label(names(pull))
      return unless held

      raise Error, "PR carries the hold label #{held.inspect} (#{SETTING}); hand it to the user as Ask. " \
                   'Only a maintainer removing the label lets it merge'
    end

    # An unread or truncated label list cannot prove the PR is not held.
    def names(pull)
      labels = Hash.try_convert(pull['labels']) || {}
      names = node_names(labels['nodes'])
      return names if names && labels['totalCount'] == names.length

      raise Error, "GitHub did not return the PR's complete label list to check #{SETTING}; hand it to the user as Ask"
    end

    private

    def node_names(nodes)
      names = Array.try_convert(nodes)&.map { |node| Hash.try_convert(node)&.fetch('name', nil) }
      names if names&.all?(String)
    end
  end
end
