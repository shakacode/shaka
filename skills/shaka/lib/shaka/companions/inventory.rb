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

      # Front matter that cannot be read counts as explicit-only, so a broken file never raises a mode.
      def explicit_front(text)
        match = text.match(/\A---\r?\n(.*?)\r?\n---\s*$/m)
        return false unless match

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

    # Reads pack files from their three homes and turns each skill into resolver entries with
    # its installed copy. Repository packs and project skills come only from the trusted commit.
    class Inventory
      include SkillFacts

      PACKAGED = File.expand_path('../../../config/packs', __dir__)
      PACKS = Configuration::Paths::PACKS

      attr_reader :warnings

      # `sha` is the verified trusted commit, or nil to read no repository layer at all.
      def initialize(home:, root:, sha:, points:)
        @home = home
        @root = root
        @sha = sha
        @points = points
        @warnings = []
        @scan = InstalledSkills.new(home:) if home
      end

      def entries
        installed = @scan ? @scan.all : []
        @warnings.concat(@scan.unread) if @scan
        packs.flat_map { |pack| pack.skills.map { |skill| entry(pack, skill, installed) } }
      end

      def packs = packaged + personal + repository

      private

      def packaged = local_files(PACKAGED).map { |path| known!(parse(File.read(path), 'packaged', path)) }

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

        source = TrustedConfigSource.new(root: @root)
        output.split("\0").filter_map do |row|
          metadata, name = row.split("\t", 2)
          next unless metadata.split[0] == '100644' && name.end_with?('.yml')

          path = "#{PACKS}/#{name}"
          known(parse(source.read_prompt(path, @sha, path), 'repository', "#{path} at #{@sha}"))
        end
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

      def project_entry(pack, skill)
        identity = "repository:#{skill.path}"
        file = "#{skill.path}/SKILL.md"
        resolved = trusted_file(file)
        unless resolved
          return build(pack, skill, identity:, installed: false, location: nil, revision: nil, explicit_front: nil)
                 .with(candidate_only: File.file?(File.join(@root, file)))
        end

        text = TrustedConfigSource.new(root: @root).read_prompt(resolved, @sha, file)
        build(pack, skill, identity:, installed: true, location: "#{@sha}:#{skill.path}", revision: @sha,
                           explicit_front: explicit_front(text))
      end

      # The path of a regular file at the trusted commit, following its links, or nil.
      def trusted_file(file)
        resolved, found = TrustedPathResolver.new(root: @root, sha: @sha).resolve(file)
        resolved if found&.last == 'blob' && found.first != TrustedPathResolver::SYMLINK.first
      end

      def installed_entry(pack, skill, installed)
        copy = installed.find { |candidate| candidate.name == skill.name && ours?(pack, candidate) }
        unless copy
          return build(pack, skill, identity: "#{pack.source}##{skill.name}", installed: false, location: nil,
                                    revision: nil, explicit_front: nil)
        end

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
