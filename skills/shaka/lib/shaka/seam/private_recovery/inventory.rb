# frozen_string_literal: true

module Shaka
  class Seam
    # Inventories recoverable content without following symlinks.
    class PrivateRecovery
      private

      def inventory_for(tree)
        entries = []
        Dir.children(tree).sort.each { |name| visit_entry(File.join(tree, name), tree, entries) }
        entries.sort_by { |entry| entry.fetch('path') }
      end

      def visit_entry(path, tree, entries)
        stat = File.lstat(path)
        entry = { 'path' => path.delete_prefix("#{tree}/"), 'mode' => stat.mode & 0o7777 }
        classify_entry(path, stat, entry)
        entries << entry
        return unless stat.directory?

        Dir.children(path).sort.each { |name| visit_entry(File.join(path, name), tree, entries) }
      end

      def classify_entry(path, stat, entry)
        return entry['type'] = 'directory' if stat.directory?

        if stat.symlink?
          entry['type'] = 'symlink'
          entry['target'] = File.readlink(path)
          return
        end
        raise Error, "Unsupported recovery entry: #{path}" unless stat.file?

        entry['type'] = 'regular'
        entry['sha256'] = file_digest(path)
      end

      def file_digest(path) = Digest::SHA256.file(path).hexdigest

      def current_inventory
        path = File.join(@storage, 'current')
        File.directory?(path) ? inventory_for(path) : nil
      end

      def compare_with_checkout
        current = current_inventory
        tree = File.join(@root, PRIVATE_DIRECTORY)
        return [] unless current && File.directory?(tree) && !File.symlink?(tree)

        old = inventory_index(current)
        now = inventory_index(inventory_for(tree))
        (old.keys | now.keys).sort.reject { |path| old[path] == now[path] }
      end

      def inventory_index(entries) = entries.to_h { |entry| [entry.fetch('path'), entry] }

      def complete_tree?
        required = [Configuration::Paths::NEW_CONTRACT, *Configuration::Paths::NEW_REQUIRED_COMMANDS.values]
        required.all? do |relative|
          path = File.join(@root, relative)
          File.file?(path) && !File.symlink?(path)
        end
      end

      def hidden_untracked(adopted)
        tree = File.join(@root, PRIVATE_DIRECTORY)
        return [] unless File.directory?(tree) && !File.symlink?(tree)

        inventory_for(tree).reject { |entry| entry['type'] == 'directory' }
                           .map { |entry| "#{PRIVATE_DIRECTORY}/#{entry.fetch('path')}" }
                           .reject { |path| adopted.include?(path) }
      end
    end
  end
end
