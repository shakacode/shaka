# frozen_string_literal: true

require 'yaml'
require_relative '../error'

module Shaka
  # The lowest review effort a description may claim, computed from the paths its PR changes,
  # so an agent's own rating cannot tell a reviewer to skip code that reaches every task.
  class ReviewEffortFloor
    PATH = File.expand_path('../../../config/review-effort-floors.yml', __dir__)
    GLOB = File::FNM_PATHNAME | File::FNM_EXTGLOB | File::FNM_DOTMATCH
    NONE = { 'level' => 1 }.freeze

    def self.rules
      @rules ||= YAML.safe_load_file(PATH, permitted_classes: [], aliases: false).fetch('floors')
    end

    # Returns the highest matching floor with its reason and the first path that set it, or NONE.
    def self.for(paths, rules = self.rules)
      matches = rules.filter_map do |rule|
        path = paths.find { |candidate| match?(rule, candidate) }
        rule.merge('path' => path) if path
      end
      matches.max_by { |rule| rule['level'] } || NONE
    end

    def self.match?(rule, path)
      return true if glob?(rule['paths'], path) || word?(rule, path)

      !rule['all_except'].nil? && !glob?(rule['all_except'], path)
    end

    def self.word?(rule, path)
      words = Array(rule['words']).flat_map { |word| [word, "#{word}s"] }
      path.downcase.split(/[^a-z0-9]+/).intersect?(words) && !glob?(rule['words_except'], path)
    end

    def self.glob?(globs, path) = Array(globs).any? { |glob| File.fnmatch?(glob, path, GLOB) }

    private_class_method :match?, :word?, :glob?
  end
end
