# frozen_string_literal: true

require 'open3'
require 'yaml'
require_relative '../error'
require_relative '../trusted_config_source'
require_relative '../trusted_path_resolver'
require_relative '../configuration/paths'
require_relative 'pack'
require_relative 'resolver'

module Shaka
  module Companions
    # Reads a project skill's files and links at the trusted commit, never from the checkout.
    module TrustedProjectFacts
      private

      # A trusted SKILL.md the reader refuses, such as an empty or oversized one, counts as explicit-only.
      def trusted_front(resolved)
        explicit_front(TrustedConfigSource.new(root: @root).read_prompt(resolved, @sha, 'project skill'))
      rescue Error => e
        @warnings << e.message
        true
      end

      # A file with no `---` header allows model invocation. Front matter that is unterminated or
      # cannot be parsed counts as explicit-only, so a broken header never raises a mode.
      def explicit_front(text)
        return true unless text.valid_encoding?
        return false unless text.match?(/\A---\r?\n/)

        match = text.match(/\A---\r?\n(.*?)\r?\n---[ \t]*\r?$/m)
        return true unless match

        data = YAML.safe_load(match[1], aliases: false)
        data.is_a?(Hash) ? data['disable-model-invocation'] == true : true
      rescue Psych::Exception
        true
      end

      # The path of a regular file at the trusted commit, following its links, or nil. A link the
      # resolver refuses, such as one leaving the repository, is warned about and treated as missing.
      def trusted_file(file)
        resolved, found = TrustedPathResolver.new(root: @root, sha: @sha).resolve(file)
        resolved if found&.last == 'blob' && found.first != TrustedPathResolver::SYMLINK.first
      rescue Error => e
        @warnings << e.message
        nil
      end

      # Declined as candidate-only only when the trusted commit has nothing at that path at all.
      def candidate_only?(file)
        File.file?(File.join(@root, file)) && TrustedPathResolver.new(root: @root, sha: @sha).entry(file).nil?
      end

      def trusted_directory(path) = TrustedPathResolver.new(root: @root, sha: @sha).resolve(path).first
    end

    # Reads the repository's pack files and turns each skill into a resolver entry. Pack files and
    # project skills come only from the trusted commit; a candidate branch's copies are never read.
    class Inventory
      include TrustedProjectFacts

      PACKS = Configuration::Paths::PACKS

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
        unless metadata.start_with?('100644 ')
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

      # The identity is the skill directory resolved in the trusted tree, so two entries that reach
      # the same directory through a link share their limits, and a link the candidate adds changes nothing.
      def entry(pack, skill)
        file = "#{skill.path}/SKILL.md"
        resolved = trusted_file(file)
        unless resolved
          return build(pack, skill, identity: "repository:#{skill.path}", installed: false, location: nil,
                                    explicit_front: nil).with(candidate_only: candidate_only?(file))
        end

        build(pack, skill, identity: "repository:#{trusted_directory(skill.path)}", installed: true,
                           location: "#{@sha}:#{skill.path}", explicit_front: trusted_front(resolved))
      end

      def build(pack, skill, **facts)
        Resolver::Entry.new(layer: 'repository', pack: pack.name, skill:, candidate_only: false,
                            revision: facts[:installed] ? @sha : nil, **facts)
      end
    end
  end
end
