# frozen_string_literal: true

require 'digest'
require 'open3'
require 'pathname'
require_relative '../configuration'
require_relative '../configuration/wrapper_template'
require_relative 'upgrade_plan/inventory'
require_relative 'upgrade_plan/command_repair'
require_relative 'upgrade_plan/root_repair'
require_relative 'upgrade_plan/references'

module Shaka
  class Seam
    # A complete, deterministic inventory. No method in this class writes to the checkout.
    class UpgradePlan
      PATHS = Configuration::Paths
      OLD_ROOT = 'root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)'
      GIT_ROOT = Configuration::WrapperTemplate::SHELL_ROOT
      RUBY_ROOT = "root = IO.popen(['git', '-C', __dir__, 'rev-parse', '--show-toplevel'], &:read).strip\n" \
                  "abort 'Cannot find repository root' unless $?.success? && !root.empty?"
      HISTORICAL = %r{\A(?:CHANGELOG|HISTORY|docs/migration\.md|internal/)}

      include Inventory
      include CommandRepair
      include RootRepair
      include References

      attr_reader :changes, :blockers, :report

      def initialize(root)
        @root = root
        @changes = []
        @blockers = []
        @references = []
        @links = []
        @repairs = []
        @moves = []
      end

      def build
        preflight_directories
        layout = Configuration::Layout.worktree(root: @root, allow_missing: true)
      rescue Shaka::Error => e
        @blockers << "#{e.message}; resolve the partial migration before retrying"
        finish_report(nil)
      else
        inventory(layout)
        scan_references if layout == Configuration::Layout::LEGACY
        dirty_overlap
        finish_report(layout)
      end

      def finish_report(layout)
        @report = {
          'mode' => 'preview', 'status' => status(layout), 'moves' => @moves.sort_by { |item| item['from'] },
          'repairs' => @repairs.sort_by { |item| item['path'] },
          'symlinks' => @links.sort_by { |item| item['from'] },
          'references' => @references.sort_by { |item| item['path'] },
          'blockers' => @blockers.uniq.sort,
          'validation' => ['shaka seam check --root DIR --local',
                           'Run moved setup, validation, and test commands with harmless inputs; compare behavior.'],
          'digest' => digest
        }
      end

      def entries
        @changes.flat_map { |change| [change.fetch(:from), change.fetch(:to)] }.uniq.sort
      end

      def desired_states
        states = entries.to_h { |path| [path, snapshot(path)] }
        @changes.each do |change|
          states[change[:to]] = change.fetch(:after)
          states[change[:from]] = absent if change[:from] != change[:to]
        end
        states
      end

      def original_states = entries.to_h { |path| [path, snapshot(path)] }

      def snapshot(relative)
        absolute = File.join(@root, relative)
        stat = File.lstat(absolute)
        return { 'type' => 'symlink', 'target' => File.readlink(absolute) } if stat.symlink?
        return file_state(absolute, stat) if stat.file?

        { 'type' => 'unsupported' }
      rescue Errno::ENOENT, Errno::ENOTDIR
        absent
      end

      def file_state(absolute, stat)
        { 'type' => 'file', 'mode' => stat.mode & 0o7777,
          'data' => [File.binread(absolute)].pack('m0') }
      end

      private

      def absent = { 'type' => 'absent' }

      def status(layout)
        return 'blocked' if @blockers.any?
        return 'already_upgraded' if layout == Configuration::Layout::NEW

        'ready'
      end

      def digest
        payload = @changes.map do |change|
          [change[:from], change[:to], snapshot(change[:from]), snapshot(change[:to]), change[:after]]
        end
        Digest::SHA256.hexdigest(Marshal.dump(payload.sort_by(&:first)))
      end

      def preflight_directories
        [PATHS::DIRECTORY, PATHS::COMMAND_DIRECTORY, File.dirname(PATHS::NEW_CONTRACT),
         PATHS::NEW_COMMAND_DIRECTORY].each do |relative|
          path = File.join(@root, relative)
          next unless File.exist?(path) || File.symlink?(path)

          @blockers << "#{relative}: expected a real directory" if File.symlink?(path) || !File.directory?(path)
        end
      end
    end
  end
end
