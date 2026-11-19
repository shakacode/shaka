# frozen_string_literal: true

require 'open3'

module ShakaDocs
  # Keep listed paths and Git link modes available before any filesystem read filters.
  module Inventory
    module_function

    def paths(repository)
      listed = if git?(repository)
                 git_output(repository, '--cached', '--others', '--exclude-standard').split("\0")
               else
                 Dir.glob('**/*', File::FNM_DOTMATCH, base: repository)
               end
      listed.uniq
    end

    def symlinks(repository)
      return [] unless git?(repository)

      git_output(repository, '--stage').split("\0").filter_map do |entry|
        entry.split("\t", 2)[1] if entry.start_with?('120000 ')
      end
    end

    def files(repository, pattern)
      indexed = symlinks(repository).map { |path| File.join(repository, path) }
      paths(repository).grep(pattern).select { |file| source_file?(repository, file, indexed) }
    end

    def source_file?(repository, file, indexed)
      path = File.join(repository, file)
      if aliased?(File.dirname(path), repository, indexed)
        raise ArgumentError, "Source aliases are not supported: #{file}"
      end

      if link?(path, indexed)
        return false if !indexed.include?(path) && !File.exist?(path)

        raise ArgumentError, "Source aliases are not supported: #{file}"
      end

      File.file?(path)
    end

    def components(path, repository)
      parts = []
      prefix = "#{repository.delete_suffix('/')}/"
      while path != repository && path.start_with?(prefix)
        parts << path
        path = File.dirname(path)
      end
      parts
    end

    def aliased?(path, repository, indexed)
      components(path, repository).reverse.any? { |part| link?(part, indexed) }
    end

    def link?(path, indexed) = indexed.include?(path) || File.symlink?(path)

    def git?(repository) = File.exist?(File.join(repository, '.git'))

    def git_output(repository, *options)
      output, error, status = Open3.capture3('git', '-C', repository, 'ls-files', *options, '-z')
      raise ArgumentError, "Cannot inventory documentation: #{error}" unless status.success?

      output
    end
  end
end
