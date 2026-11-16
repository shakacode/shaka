# frozen_string_literal: true

require_relative 'pack'

module Shaka
  module Companions
    # Decides each companion skill's mode at one skill point from every pack layer. Pure: the
    # caller reads files, finds installed copies, and passes the facts in.
    #
    # Entries for one skill share an identity: its installed path, a project skill's path,
    # or its source and name when nothing is installed. Every rule below applies per identity,
    # so declaring a skill again under another pack name inherits its limits.
    class Resolver
      # `explicit_front` is the installed SKILL.md's model-invocation flag: true, false, or nil
      # when nothing is installed. `candidate_only` marks a project skill missing from the trusted commit.
      Entry = Data.define(:layer, :pack, :skill, :identity, :installed, :location, :revision,
                          :explicit_front, :candidate_only)
      Row = Data.define(:point, :pack, :skill, :layer, :mode, :reason, :basis, :installed, :location, :revision)

      RANK = Pack::MODES.each_with_index.to_h.freeze
      CANDIDATE_ONLY = ['decline', 'it exists only on the candidate branch', 'no trusted copy to load'].freeze

      # `enabled_packs` lists packs whose packaged `use` entries apply. `trusted` is false when no
      # trusted ref was given; repository entries then never apply.
      def initialize(entries, enabled_packs: [], trusted: true)
        @entries = trusted ? entries : entries.reject { |entry| entry.layer == 'repository' }
        @enabled = enabled_packs
      end

      def call(point)
        @entries.group_by(&:identity).filter_map { |_identity, group| resolve(point, group) }
      end

      private

      def resolve(point, group)
        settings = group.filter_map { |entry| setting(entry, point) }
        return if settings.empty?

        entry, mode, reason = governing(settings)
        mode, basis = cap(entry, mode, group)
        mode, basis, reason = declined(settings, group, [mode, basis, reason])
        row(point, entry, mode, reason, basis)
      end

      # [entry, mode, reason] at this point; the point's own setting wins over the pack's `*`.
      def setting(entry, point)
        points = entry.skill.points
        mode, reason = points[point] || points[Pack::ANY]
        [entry, mode, reason] if mode
      end

      # The repository's own entry governs; otherwise packaged, then personal. Within one layer
      # the strictest mode wins.
      def governing(settings)
        layer = Pack::LAYERS.values_at(1, 0, 2).find { |name| settings.any? { |entry, _, _| entry.layer == name } }
        settings.select { |entry, _, _| entry.layer == layer }.min_by { |_, mode, _| RANK.fetch(mode) }
      end

      def cap(entry, mode, group)
        return [mode, "#{entry.layer} entry"] if mode != 'use'

        limit = use_limit(entry) || install_limit(group) || flag_limit(group)
        limit ? ['suggest', limit] : ['use', "#{entry.layer} entry"]
      end

      def use_limit(entry)
        case entry.layer
        when 'personal' then 'a personal pack entry suggests at most'
        when 'packaged' then "the #{entry.pack} pack is not turned on" unless @enabled.include?(entry.pack)
        end
      end

      def install_limit(group) = ('it is not installed' unless group.all?(&:installed))

      # Fans-out never reaches use. Explicit-only needs both the repository's cleared flag and
      # installed front matter that allows model invocation. Setup is a default the repository may clear.
      def flag_limit(group)
        return 'it fans out workers' if group.any? { |entry| entry.skill.flags['fans_out'] }
        return 'it is explicit-only' if explicit?(group)

        'it is one-time setup' if flag(group, 'setup')
      end

      def explicit?(group) = flag(group, 'explicit_only') || group.any? { |entry| entry.explicit_front != false }

      # Only the repository's own entries can clear a flag another layer sets; when several state
      # it, any one that sets it wins, so file order never decides.
      def flag(group, name)
        own = group.select { |entry| entry.layer == 'repository' && entry.skill.flags.key?(name) }
        return own.any? { |entry| entry.skill.flags[name] } unless own.empty?

        group.any? { |entry| entry.skill.flags[name] }
      end

      # Declines apply last: a personal decline, and a packaged one the repository did not
      # override, beat every other mode. A candidate-only project skill has no trusted copy.
      def declined(settings, group, result)
        return CANDIDATE_ONLY if group.any?(&:candidate_only)
        return result if result.first == 'decline'

        decline = overriding_decline(settings)
        decline ? ['decline', "#{decline.first.layer} decline", decline.last] : result
      end

      def overriding_decline(settings)
        repository = settings.any? { |entry, _, _| entry.layer == 'repository' }
        settings.find { |entry, mode, _| mode == 'decline' && (entry.layer == 'personal' || !repository) }
      end

      def row(point, entry, mode, reason, basis)
        Row.new(point:, pack: entry.pack, skill: entry.skill.name, layer: entry.layer, mode:, reason:, basis:,
                installed: entry.installed, location: entry.location, revision: entry.revision)
      end
    end
  end
end
