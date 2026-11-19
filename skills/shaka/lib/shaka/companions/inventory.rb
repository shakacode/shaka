# frozen_string_literal: true

require 'open3'
require 'yaml'
require_relative '../error'
require_relative '../trusted_config_source'
require_relative '../trusted_path_resolver'
require_relative '../configuration/paths'
require_relative '../repository_config/duplicate_keys'
require_relative 'pack'
require_relative 'resolver'

module Shaka
  module Companions
    # Reads a project skill's files at the trusted commit, never from the checkout.
    module TrustedProjectFacts
      private

      # A trusted SKILL.md the reader refuses, such as an empty or oversized one, counts as explicit-only.
      def trusted_front(file)
        explicit_front(TrustedConfigSource.new(root: @root).read_prompt(file, @sha, 'project skill'))
      rescue Error => e
        @warnings << e.message
        true
      end

      # A file with no `---` header allows model invocation. Front matter that is empty, unterminated,
      # unparsable, or repeats a key counts as explicit-only, and so does any `disable-model-invocation`
      # value but `false`, so a broken or unusual header never raises a mode.
      def explicit_front(text)
        return true unless text.valid_encoding?

        text = text.delete_prefix("\uFEFF")
        return false unless text.match?(/\A---[ \t]*(\r?\n|\z)/)

        match = text.match(/\A---[ \t]*\r?\n(.*?)^---[ \t]*\r?$/m)
        return true unless match

        header_explicit?(match[1])
      rescue Psych::Exception, Error
        true
      end

      def header_explicit?(header)
        RepositoryConfig::DuplicateKeys.check(header, filename: 'front matter')
        data = YAML.safe_load(header, aliases: false)
        return true unless data.is_a?(Hash)

        data.key?('disable-model-invocation') && data['disable-model-invocation'] != false
      end

      # True when the trusted commit holds `file` as a regular file reached without links. A skill
      # reached through a link is not supported yet, so it is warned about and treated as missing.
      def trusted_file?(file)
        resolved, found = TrustedPathResolver.new(root: @root, sha: @sha).resolve(file)
        regular = found&.last == 'blob' && found.first != TrustedPathResolver::SYMLINK.first
        return regular if !regular || resolved == file

        @warnings << "#{file} at #{@sha} is reached through a link; linked skill paths are not supported"
        false
      rescue Error => e
        @warnings << e.message
        false
      end

      # A checkout copy counts as candidate-only when the trusted commit has nothing at that path.
      def candidate_only?(file)
        File.file?(File.join(@root, file)) && TrustedPathResolver.new(root: @root, sha: @sha).entry(file).nil?
      end
    end

    # Reads the repository's pack files and turns each skill into a resolver entry. Pack files and
    # project skills come only from the trusted commit; a candidate branch's copies are never read.
    class Inventory
      include TrustedProjectFacts

      PACKS = Configuration::Paths::PACKS
      REGULAR_MODES = %w[100644 100755].freeze

      attr_reader :warnings

      # `sha` is the verified trusted commit, or nil to read no packs at all.
      def initialize(root:, sha:, points:)
        @root = root
        @sha = sha
        @points = points
        @warnings = []
      end

      def entries = packs.flat_map { |pack| pack.skills.map { |skill| entry(pack, skill) } }

      private

      # Only regular files at the trusted commit.
      def packs
        return [] unless @sha

        output, _error, status = Open3.capture3('git', '-C', @root, 'ls-tree', '-z', "#{@sha}:#{PACKS}")
        return [] unless status.success?

        output.split("\0").filter_map { |row| trusted_pack(*row.split("\t", 2)) }
      end

      def trusted_pack(metadata, name)
        return unless name.end_with?('.yml')

        path = "#{PACKS}/#{name}"
        unless REGULAR_MODES.include?(metadata.split.first)
          @warnings << "#{path} at #{@sha} skipped: not a regular file"
          return
        end

        text = TrustedConfigSource.new(root: @root).read_prompt(path, @sha, path)
        known(Pack.parse(text, label: "#{path} at #{@sha}"))
      end

      # A pack naming a point no procedure declares keeps its other points and warns.
      def known(pack)
        unknown = pack.skills.flat_map { |skill| skill.points.keys }.uniq - @points - [Pack::ANY]
        unknown.each { |point| @warnings << "#{pack.label}: unknown skill point #{point} ignored" }
        pack
      end

      # `location` and `skill_file` name the skill's directory and SKILL.md at the trusted commit.
      def entry(pack, skill)
        file = "#{skill.path}/SKILL.md"
        facts = { identity: "repository:#{skill.path}", location: nil, skill_file: nil, explicit_front: nil }
        unless trusted_file?(file)
          return build(pack, skill, installed: false, **facts).with(candidate_only: candidate_only?(file))
        end

        build(pack, skill, installed: true, **facts, location: "#{@sha}:#{skill.path}",
                           skill_file: "#{@sha}:#{file}", explicit_front: trusted_front(file))
      end

      def build(pack, skill, **facts)
        Resolver::Entry.new(layer: 'repository', pack: pack.name, skill:, candidate_only: false,
                            revision: facts[:installed] ? @sha : nil, **facts)
      end
    end
  end
end
