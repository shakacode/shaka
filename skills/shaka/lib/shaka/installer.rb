# frozen_string_literal: true

require 'shellwords'
require_relative 'install/tree'
require_relative 'install/source'
require_relative 'install/package'
require_relative 'install/links'

module Shaka
  # Installs a checkout independent copy and points one host's skills directory to it.
  class Installer
    def initialize(source_root:, skills_dir:, names:, rollback: nil)
      @source_root = File.realpath(source_root)
      @skills_dir = File.expand_path(skills_dir)
      @names = names
      @rollback = rollback
      @managed = File.join(Dir.home, '.local/share/shaka/installs')
      refuse_overlap
    end

    def run
      tree = Install::Tree.new(@names)
      source = Install::Source.new(@source_root, @names, tree)
      package = Install::Package.new(@managed, source, @names, tree)
      target = @rollback ? package.existing(@rollback) : package.prepare(@source_root)
      Install::Links.new(@skills_dir, @managed, @source_root, @names, package).switch_all(target)
      puts "Package: #{File.basename(target)}"
      puts "Next: #{Shellwords.escape(File.join(@skills_dir, 'shaka/scripts/shaka'))} seam init --help"
    end

    private

    def refuse_overlap
      [@managed, @skills_dir].each do |path|
        next unless path == @source_root || path.start_with?("#{@source_root}/")

        raise ArgumentError, 'Installation overlaps source checkout'
      end
    end
  end
end
