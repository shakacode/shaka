# frozen_string_literal: true

module Shaka
  module Install
    # Finds skills, and skills folders, that reach into a set of folders through any symbolic link on the way,
    # so a step that removes those folders is not printed while a link would be left pointing at nothing.
    module WorktreeLinks
      HOPS = 40

      module_function

      # Each folder, or each entry in it, that reaches into one of roots. A folder that cannot be listed has
      # nothing to check.
      def into(roots, folders)
        roots = roots.flat_map { |root| [File.expand_path(root), real(root)] }.compact.uniq
        return [] if roots.empty?

        folders.compact.uniq.flat_map do |folder|
          next [folder] if reaches?(folder, roots)

          entries(folder).select { |entry| reaches?(entry, roots) }
        end
      end

      def entries(folder)
        Dir.children(folder).sort.map { |name| File.join(folder, name) }
      rescue SystemCallError
        []
      end

      # A link inside a root that leads back out still passes through the root, so every path on the way
      # counts, not only where it ends.
      def reaches?(path, roots)
        Walk.new(path).each { |step| return true if inside?(step, roots) }
        false
      rescue SystemCallError
        false
      end

      def names(path) = path.split('/').reject { |name| name.empty? || name == '.' }

      def inside?(path, roots) = roots.any? { |root| path == root || path.start_with?("#{root}/") }

      def real(path)
        File.realpath(path)
      rescue SystemCallError
        nil
      end

      # Resolves one path a name at a time, following each link where it appears. A chain longer than the
      # system allows stops early, as it opens nothing.
      class Walk
        def initialize(path)
          @pending = WorktreeLinks.names(File.expand_path(path))
          @current = '/'
          @hops = 0
        end

        def each
          yield step until @pending.empty? || @hops > HOPS
        end

        private

        def step
          name = @pending.shift
          return @current = File.dirname(@current) if name == '..'

          candidate = File.join(@current, name)
          if File.symlink?(candidate)
            follow(candidate)
          else
            @current = candidate
          end
          candidate
        end

        def follow(link)
          target = File.readlink(link)
          @current = '/' if target.start_with?('/')
          @pending.unshift(*WorktreeLinks.names(target))
          @hops += 1
        end
      end
    end
  end
end
