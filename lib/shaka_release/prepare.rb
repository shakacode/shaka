# frozen_string_literal: true

require 'fileutils'
require_relative 'preflight'
require_relative 'shell'

module ShakaRelease
  # Builds and checks every release input, then writes the approval file `publish` reads.
  # It changes no remote state.
  class Prepare
    include Shell

    # `options` takes `validation` (an existing result to reuse), `behavior_records`, and
    # `skip_behavior_gate`.
    def initialize(root:, shaka:, out:, **options)
      @root = File.realpath(root)
      @shaka = shaka
      @out = File.expand_path(out)
      @validation = options[:validation]
      @behavior_records = options.fetch(:behavior_records, [])
      @skip_behavior_gate = options.fetch(:skip_behavior_gate, false)
    end

    def run
      check_out_directory
      commit = run!({}, 'git', '-C', @root, 'rev-parse', 'HEAD').strip
      gate = behavior_gate(commit)
      validation = @validation || run_validation(commit)
      approval = preflight(commit, validation).merge('validation' => File.expand_path(validation),
                                                     'behavior_gate' => gate)
      File.write(File.join(@out, 'approval.json'), "#{JSON.pretty_generate(approval)}\n")
      approval
    end

    private

    def preflight(commit, validation)
      version = Dir.chdir(@root) { Gem::Specification.load('shaka.gemspec') }&.version&.to_s
      refuse 'Cannot load source gemspec' unless version
      gem = build_gem(version)
      notes = write_notes(version)
      Preflight.new(root: @root, shaka: @shaka, commit:, gem:, validation:, notes:).check
               .merge('gem' => gem, 'notes' => notes)
    end

    def check_out_directory
      FileUtils.mkdir_p(@out)
      @out = File.realpath(@out)
      refuse 'the output directory must be outside the release checkout' if "#{@out}/".start_with?("#{@root}/")
    end

    # Runs before validation so a missing or failing batch stops the release in seconds.
    def behavior_gate(commit)
      refuse 'choose --behavior-records or --skip-behavior-gate' if @skip_behavior_gate == @behavior_records.any?
      return { 'status' => 'skipped' } if @skip_behavior_gate

      { 'status' => 'passed', 'records' => @behavior_records.map { check_behavior(it, commit) } }
    end

    def check_behavior(path, commit)
      require_relative '../../eval/lib/shaka/evaluation/release_behavior'
      records = JSON.parse(File.read(path, encoding: 'UTF-8'))
      result = Shaka::Evaluation::ReleaseBehavior.new(records:, skill: File.join(@root, 'skills/shaka'), commit:).check
      refuse "release behavior batch did not pass: #{path}" unless result['status'] == 'passed'
      { 'path' => File.expand_path(path), 'sha256' => Digest::SHA256.file(path).hexdigest }
    rescue ArgumentError, JSON::ParserError, SystemCallError => e
      refuse "release behavior batch is unreadable or invalid: #{e.class}"
    end

    def run_validation(commit)
      path = File.join(@out, 'validation.json')
      # The helper writes its result JSON to stdout and the command's own output to stderr.
      output, status = Open3.capture2(@shaka, 'evidence', 'run', '--root', @root, '--ref', commit,
                                      '--repository', 'shakacode/shaka', '--command', 'validate')
      File.write(path, output)
      refuse "validation helper failed; its result is in #{path}" unless status.success?
      path
    end

    def build_gem(version)
      path = File.join(@out, "shaka-#{version}.gem")
      Dir.chdir(@root) { run!({}, 'gem', 'build', 'shaka.gemspec', '--output', path) }
      path
    end

    def write_notes(version)
      entry = Preflight.changelog_entry(@root, version)
      refuse "CHANGELOG.md has no entry for #{version}" unless entry && !entry.strip.empty?
      path = File.join(@out, 'RELEASE_NOTES.md')
      File.write(path, "#{entry.strip}\n")
      path
    end
  end
end
