# frozen_string_literal: true

module Shaka
  module Install
    # Finds skills, and skills folders, that reach into a set of folders through any symbolic link on the way,
    # so a step that removes those folders is not printed while a link would be left pointing at nothing.
    module WorktreeLinks
      HOPS = 40

      module_function

      # Each folder, or each entry in it, that reaches into one of roots. A folder or path that cannot be read
      # is named too, since nothing shows its links are safe; a folder that does not exist holds none.
      def into(roots, folders)
        roots = Roots.new(roots)
        return [] if roots.empty?

        folders.compact.map { |folder| expanded(folder) }.uniq.flat_map do |folder|
          next [folder] if reaches?(folder, roots)

          entries = listing(folder)
          entries ? entries.select { |entry| reaches?(entry, roots) } : [folder]
        end
      end

      # nil when the folder exists but cannot be listed.
      def listing(folder)
        Dir.children(folder).sort.map { |name| File.join(folder, name) }
      rescue Errno::ENOENT, Errno::ENOTDIR
        []
      rescue SystemCallError
        nil
      end

      # A folder named as ~user for an unknown user stays as given, and the walk names it as unreadable.
      def expanded(folder)
        File.expand_path(folder)
      rescue ArgumentError
        folder
      end

      # A link inside a root that leads back out still passes through the root, so every path on the way
      # counts, not only where it ends. A path that cannot be looked up, or expanded, may reach a root.
      def reaches?(path, roots)
        Walk.new(path).each { |step| return true if roots.include?(step) }
        false
      rescue SystemCallError, ArgumentError
        true
      end

      def names(path) = path.split('/').reject { |name| name.empty? || name == '.' }

      # The folders a step removes, matched by spelling and by file identity, so a path that differs only in
      # case on a case-insensitive volume still matches.
      class Roots
        def initialize(paths)
          @spellings = paths.flat_map { |path| [File.expand_path(path), real(path)] }.compact.uniq
          @identities = paths.filter_map { |path| identity(path) }.uniq
        end

        def empty? = @spellings.empty?

        def include?(path)
          @spellings.any? { |root| path == root || path.start_with?("#{root}/") } ||
            ancestors(path).any? { |ancestor| @identities.include?(identity(ancestor)) }
        end

        private

        def ancestors(path)
          [path].tap { |list| list << File.dirname(list.last) until File.dirname(list.last) == list.last }
        end

        def identity(path)
          stat = File.stat(path)
          [stat.dev, stat.ino]
        rescue SystemCallError
          nil
        end

        def real(path)
          File.realpath(path)
        rescue SystemCallError
          nil
        end
      end

      # Resolves one path a name at a time, following each link where it appears. A missing name, or one under
      # a file, ends the walk there, as the system resolves no further; a lookup it is denied raises. A chain
      # longer than the system allows stops early, as it opens nothing.
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
          if link?(candidate)
            follow(candidate)
          else
            @current = candidate
          end
          candidate
        end

        def link?(path)
          File.lstat(path).symlink?
        rescue Errno::ENOENT, Errno::ENOTDIR
          @pending.clear
          false
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
