# frozen_string_literal: true

require 'rbconfig'
require_relative 'install/tree'
require_relative 'install/source'
require_relative 'install/package'
require_relative 'install/links'

module Shaka
  # Copies a checkout into a verified package for a PR trial; see install/README.md.
  class Installer
    RUBY_RECORD = '.shaka-ruby'

    def initialize(source_root:, skills_dir:, names:, managed_dir:)
      @source_alias = File.expand_path(source_root)
      @source_root = File.realpath(source_root)
      @skills_dir = canonical(skills_dir)
      @names = Install::Package.ordered_skills(names)
      @managed = canonical(managed_dir)
      refuse_overlap
    end

    def run(link: true)
      tree = Install::Tree.new(@names, source_root: @source_root, source_alias: @source_alias)
      source = Install::Source.new(@source_root, @names, tree)
      package = Install::Package.new(@managed, source, @names, tree)
      target = package.prepare(@source_root)
      record_ruby
      Install::Links.new(@skills_dir, @managed, @source_root, @names).switch_all(target) if link
      target
    end

    private

    # The installed helper starts with this Ruby, so the Ruby a project selects cannot stop it.
    def record_ruby
      path = File.join(@managed, RUBY_RECORD)
      staged = "#{path}.#{Process.pid}"
      File.write(staged, "#{File.realpath(RbConfig.ruby)}\n")
      File.chmod(0o644, staged)
      File.rename(staged, path)
    end

    def canonical(path)
      expanded = File.expand_path(path)
      ancestor = expanded
      ancestor = File.dirname(ancestor) until File.exist?(ancestor) || File.symlink?(ancestor)
      File.expand_path(File.join(File.realpath(ancestor), expanded.delete_prefix(ancestor).delete_prefix('/')))
    end

    def refuse_overlap
      raise ArgumentError, 'Installation overlaps source checkout' if [@managed, @skills_dir].any? do |path|
        overlap?(path, @source_root)
      end
      raise ArgumentError, 'Managed and skills directories overlap' if overlap?(@managed, @skills_dir)
    end

    def overlap?(left, right)
      left == right || left.start_with?("#{right}/") || right.start_with?("#{left}/")
    end
  end
end
