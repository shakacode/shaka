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

    def git?(repository) = File.exist?(File.join(repository, '.git'))

    def git_output(repository, *options)
      output, error, status = Open3.capture3('git', '-C', repository, 'ls-files', *options, '-z')
      raise ArgumentError, "Cannot inventory documentation: #{error}" unless status.success?

      output
    end
  end
end
