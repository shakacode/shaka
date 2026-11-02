# frozen_string_literal: true

require_relative '../defaults'

module Shaka
  # The lowest review effort a description may claim, computed from the paths its PR changes,
  # so an agent's own rating cannot tell a reviewer to skip code that reaches every task.
  class ReviewEffortFloor
    GLOB = File::FNM_PATHNAME | File::FNM_EXTGLOB | File::FNM_DOTMATCH
    NONE = { 'level' => 1 }.freeze

    def self.defaults = Defaults.fetch('pr_description', 'human_review_floors')

    # Returns the highest matching floor with its reason, the first path that set it, every file at
    # that level grouped by the floor that set it, and how many other files the PR changes; or NONE.
    # Rules come from the trusted repository settings; nil means they were not read, so the
    # shipped defaults apply and the result says so.
    def self.for(paths, rules = nil)
      floor = highest(paths, rules || defaults)
      rules ? floor : floor.merge('shipped' => true)
    end

    def self.highest(paths, rules)
      top = matches(paths, rules).group_by { |rule, _| rule['level'] }.max_by(&:first)&.last
      top ? summary(top, paths) : NONE
    end

    def self.matches(paths, rules)
      rules.filter_map do |rule|
        found = paths.select { |candidate| match?(rule, candidate) }
        [rule, found] unless found.empty?
      end
    end

    def self.summary(top, paths)
      rule, found = top.first
      groups = grouped(top)
      rule.merge('path' => found.first, 'groups' => groups,
                 'others' => paths.uniq.size - groups.sum { |group| group['paths'].size })
    end

    # A file two floors at one level both match stays with the first.
    def self.grouped(top)
      seen = []
      top.filter_map do |rule, found|
        fresh = found.uniq - seen
        seen += fresh
        { 'reason' => rule['reason'], 'paths' => fresh } unless fresh.empty?
      end
    end

    # `except` removes a file from its own floor only; another floor can still match it.
    def self.match?(rule, path)
      (glob?(rule['paths'], path) || word?(rule, path)) && !glob?(rule['except'], path)
    end

    def self.word?(rule, path)
      words = Array(rule['words']).flat_map { |word| [word.downcase, "#{word.downcase}s"] }
      tokens(path).intersect?(words)
    end

    # CamelCase names split like snake_case ones: AuthService and HTTPAuth both hold auth.
    def self.tokens(path)
      path.gsub(/([a-z0-9])([A-Z])|([A-Z])([A-Z][a-z])/, '\\1\\3 \\2\\4').downcase.split(/[^a-z0-9]+/)
    end

    def self.glob?(globs, path) = Array(globs).any? { |glob| File.fnmatch?(glob, path, GLOB) }

    private_class_method :highest, :matches, :summary, :grouped, :match?, :word?, :tokens, :glob?
  end
end
