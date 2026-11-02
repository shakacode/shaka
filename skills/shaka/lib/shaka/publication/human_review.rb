# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Renders how much of a person's attention a PR asks for. A floor comes from the files that set it, so
  # the line names those files; nothing checks how closely anyone read, so it asks modestly.
  module HumanReview
    READING = {
      1 => 'the description should be enough.',
      2 => 'skim the diff.',
      3 => 'read the walkthrough and the diff.',
      4 => 'read the riskiest files closely.',
      5 => 'read the riskiest files closely; a mistake here is hard to undo.'
    }.freeze
    # Most PRs have three or fewer files at their top floor; the rest of a long list is counted.
    NAMED_FILES = 5
    SAFE_PATH = %r{\A[\w.@+/ -]+\z}
    # The repository's floors can be stricter, so a description that never read them says so.
    SHIPPED = "Shaka's shipped floors applied because this repository's settings were not read."

    module_function

    # pull supplies GitHub's file count, which counts a rename once where the floor's paths hold both names.
    def render(effort, floor, pull = nil)
      reading = READING[effort] if effort.is_a?(Integer)
      raise Error, 'Publication intent review_effort must be a whole number from 1 to 5.' unless reading

      refuse_below_floor!(effort, floor)
      [line(effort, reading, floor, pull), *(SHIPPED if floor && floor['shipped'])].join(' ')
    end

    # A rating at its floor is about the files that set it, so the line asks only for those.
    def line(effort, reading, floor, pull)
      level = floor ? floor['level'] : 1
      return "**Human review:** #{effort} of 5, #{reading}" unless level > 1

      groups = groups(floor)
      files = "#{floor_files(groups)}.#{other_files(groups, pull)}"
      return "**Human review:** #{effort} of 5, #{reading} Floor #{level}: #{files}" if effort > level

      "**Human review:** #{effort} of 5. #{level > 2 ? 'Read' : 'Skim'} #{files}"
    end

    def refuse_below_floor!(effort, floor)
      return unless floor && effort < floor['level']

      raise Error, "Publication intent review_effort #{effort} is below this PR's floor of #{floor['level']}: " \
                   "it #{floor['reason']} (#{floor_path(floor['path'])}). Rate it #{floor['level']} or higher."
    end

    # A rendering preview runs this file against the installed floor lookup, which may predate groups.
    def groups(floor) = floor['groups'] || [{ 'reason' => floor['reason'], 'paths' => [floor['path']] }]

    def floor_files(groups)
      room = NAMED_FILES
      groups.map do |group|
        paths = group['paths']
        named = paths.first(room)
        room -= named.size
        "#{names(named, paths.size - named.size)} (#{group['reason']})".strip
      end.join(', ')
    end

    def names(named, unnamed)
      [named.map { |path| floor_path(path) }.join(', '), *("and #{unnamed} more" if unnamed.positive?)].join(' ')
    end

    def other_files(groups, pull)
      changed = pull && pull['changed_files']
      count = changed.is_a?(Integer) ? changed - groups.sum { |group| group['paths'].size } : 0
      return '' unless count.positive?

      count == 1 ? ' 1 other file sets a lower floor.' : " #{count} other files set a lower floor."
    end

    # A changed filename comes from the PR author, so only a plain one reaches the description.
    def floor_path(path) = path.match?(SAFE_PATH) ? "`#{path}`" : 'a file whose name is withheld'

    private_class_method :line, :refuse_below_floor!, :groups, :floor_files, :names, :other_files, :floor_path
  end
end
