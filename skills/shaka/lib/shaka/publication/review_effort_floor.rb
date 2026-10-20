# frozen_string_literal: true

require_relative '../defaults'

module Shaka
  # The lowest review effort a description may claim, computed from the paths its PR changes,
  # so an agent's own rating cannot tell a reviewer to skip code that reaches every task.
  class ReviewEffortFloor
    GLOB = File::FNM_PATHNAME | File::FNM_EXTGLOB | File::FNM_DOTMATCH
    NONE = { 'level' => 1 }.freeze

    def self.defaults = Defaults.fetch('pr_description', 'review_effort_floors')

    # Returns the highest matching floor with its reason and the first path that set it, or NONE.
    # Rules come from the trusted repository settings, or the shipped defaults when unread.
    def self.for(paths, rules = defaults)
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
      tokens(path).intersect?(words) && !glob?(rule['words_except'], path)
    end

    # CamelCase names split like snake_case ones: AuthService and HTTPAuth both hold auth.
    def self.tokens(path)
      path.gsub(/([a-z0-9])([A-Z])|([A-Z])([A-Z][a-z])/, '\\1\\3 \\2\\4').downcase.split(/[^a-z0-9]+/)
    end

    def self.glob?(globs, path) = Array(globs).any? { |glob| File.fnmatch?(glob, path, GLOB) }

    private_class_method :match?, :word?, :tokens, :glob?
  end
end
