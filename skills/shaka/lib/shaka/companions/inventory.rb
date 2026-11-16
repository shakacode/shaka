# frozen_string_literal: true

require 'open3'
require 'yaml'
require_relative '../error'
require_relative '../installed_skills'
require_relative '../trusted_config_source'
require_relative '../trusted_path_resolver'
require_relative '../configuration/paths'
require_relative 'pack'
require_relative 'resolver'

module Shaka
  module Companions
    # Facts read from an installed skill: its real path, front matter, and checkout revision.
    module SkillFacts
      private

      def real(path)
        File.realpath(path)
      rescue SystemCallError
        path
      end

      def front_of(path)
        explicit_front(File.read(File.join(path, 'SKILL.md')))
      rescue SystemCallError
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

      # The checkout holding a folder skill; never the home directory's own repository.
      def revision(path)
        output, _error, status = Open3.capture3('git', '-C', path, 'rev-parse', '--show-toplevel', 'HEAD')
        top, sha = output.lines.map(&:strip)
        sha if status.success? && top != real(@home.to_s)
      end
    end

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

    # Reads pack files from their three homes and turns each skill into resolver entries with
    # its installed copy. Repository packs and project skills come only from the trusted commit.
    class Inventory
      include SkillFacts
      include TrustedProjectFacts

      PACKAGED = File.expand_path('../../../config/packs', __dir__)
      PACKS = Configuration::Paths::PACKS

      attr_reader :warnings

      # `sha` is the verified trusted commit, or nil to read no repository layer at all.
      def initialize(home:, root:, sha:, points:, packaged: PACKAGED)
        @home = home
        @root = root
        @sha = sha
        @points = points
        @packaged = packaged
        @warnings = []
        @scan = InstalledSkills.new(home:) if home
      end

      def entries
        installed = @scan ? @scan.all : []
        @warnings.concat(@scan.unread) if @scan
        packs.flat_map { |pack| pack.skills.flat_map { |skill| entry(pack, skill, installed) } }
      end

      def packs = packaged + personal + repository

      private

      def packaged = local_files(@packaged).map { |path| known!(parse(File.read(path), 'packaged', path)) }

      def personal
        return [] unless @home

        local_files(File.join(@home, PACKS)).map { |path| known(parse(File.read(path), 'personal', path)) }
      end

      def local_files(directory) = Dir.glob(File.join(directory, '*.yml'))

      # Only regular files at the trusted commit; a candidate branch's packs are never read.
      def repository
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
        known(parse(text, 'repository', "#{path} at #{@sha}"))
      end

      def parse(text, layer, label) = Pack.parse(text, layer:, label:)

      # A packaged pack must name only declared points; other packs drop unknown ones with a warning.
      def known!(pack)
        unknown = unknown_points(pack)
        raise Error, "#{pack.label}: unknown skill point #{unknown.first}" unless unknown.empty?

        pack
      end

      def known(pack)
        unknown_points(pack).each { |point| @warnings << "#{pack.label}: unknown skill point #{point} ignored" }
        pack
      end

      def unknown_points(pack)
        pack.skills.flat_map { |skill| skill.points.keys }.uniq - @points - [Pack::ANY]
      end

      def entry(pack, skill, installed)
        skill.path ? project_entry(pack, skill) : installed_entry(pack, skill, installed)
      end

      def build(pack, skill, **facts)
        Resolver::Entry.new(layer: pack.layer, pack: pack.name, skill:, candidate_only: false, **facts)
      end

      # The identity is the skill directory resolved in the trusted tree and placed under the checkout
      # root, which is where a home-folder link to it resolves. An alias shares its limits, and neither
      # a linked SKILL.md nor a link the candidate branch adds changes the identity.
      def project_entry(pack, skill)
        file = "#{skill.path}/SKILL.md"
        resolved = trusted_file(file)
        unless resolved
          return build(pack, skill, identity: "repository:#{skill.path}", installed: false, location: nil,
                                    revision: nil, explicit_front: nil)
                 .with(candidate_only: candidate_only?(file))
        end

        build(pack, skill, identity: File.join(real(@root), trusted_directory(skill.path)), installed: true,
                           location: "#{@sha}:#{skill.path}", revision: @sha, explicit_front: trusted_front(resolved))
      end

      # One entry per installed copy, since each host loads its own copy and each copy has its own limits.
      def installed_entry(pack, skill, installed)
        copies = installed.select { |candidate| candidate.name == skill.name && ours?(pack, candidate) }
        if copies.empty?
          return build(pack, skill, identity: "#{pack.source}##{skill.name}", installed: false, location: nil,
                                    revision: nil, explicit_front: nil)
        end

        copies.map { |copy| copy_entry(pack, skill, copy) }
      end

      def copy_entry(pack, skill, copy)
        path = real(copy.path)
        build(pack, skill, identity: path, installed: true, location: @scan.shown(copy.path),
                           revision: copy.revision || revision(path), explicit_front: front_of(path))
      end

      # A same-named skill from somewhere else is not this pack's copy.
      def ours?(pack, copy)
        pack.match['plugins'].any? { |name| copy.origin == "#{name} plugin" } ||
          pack.match['paths'].any? { |glob| File.fnmatch?(glob, real(copy.path), File::FNM_EXTGLOB) }
      end
    end
  end
end
