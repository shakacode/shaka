# frozen_string_literal: true

require 'tmpdir'
require_relative 'reference'
require_relative '../github'
require_relative '../installer'
require_relative '../workflow_version'

module Shaka
  module Trial
    # Copies an explicitly selected source without executing it or changing the normal host link.
    class Prepare
      GIT_ENV = WorkflowVersion::GIT_ENVIRONMENT.to_h { [it, nil] }
                                                .merge('GIT_CONFIG_GLOBAL' => File::NULL,
                                                       'GIT_CONFIG_NOSYSTEM' => '1').freeze

      def initialize(url, root:, directory:, task: 'Describe your task here.', **dependencies)
        @url = url
        @number = Reference.number(url)
        @root = project_root(root)
        @directory = canonical(directory)
        @github = dependencies[:github] || GitHub.new(Reference::REPOSITORY, @number)
        @fetcher = dependencies[:fetcher] || method(:fetch)
        @task = task
      end

      def run
        refuse_overlap
        head = selected_head
        Dir.mktmpdir('shaka-trial-source-') do |scratch|
          refuse_overlap(File.realpath(scratch))
          source = File.join(scratch, 'source')
          @fetcher.call(source, @number)
          copy(source, head)
        end
      end

      private

      def selected_head
        pull = @github.api("repos/#{Reference::REPOSITORY}/pulls/#{@number}")
        Reference.public_candidate!(pull)
        raise Error, 'Select an open Shaka PR for a new trial.' unless pull['state'] == 'open'

        @source = pull.dig('head', 'repo') || {}
        Reference.head(pull.dig('head', 'sha'))
      end

      def copy(source, head)
        raise Error, 'Shaka PR moved during preparation; retry to select its new head.' unless
          git(source, 'rev-parse', 'HEAD') == head

        installer = Installer.new(source_root: source, skills_dir: File.join(@directory, 'links', @number, head),
                                  managed_dir: File.join(@directory, 'installs'), names: ['shaka'])
        package = installer.run(announce: false, link: false)
        verify_identity(package, head)
        result(package, head)
      end

      def verify_identity(package, head)
        metadata = JSON.parse(File.read(File.join(package, Install::Package::METADATA)))
        return if metadata.dig('source', 'kind') == 'revision' && metadata.dig('source', 'revision') == head

        raise Error, 'Prepared package is not the exact selected revision.'
      end

      def result(package, head)
        skill = File.join(package, 'skills/shaka/SKILL.md')
        helper = File.join(package, 'skills/shaka/scripts/shaka')
        { 'candidate_url' => @url, 'candidate_head' => head, 'skill' => skill, 'helper' => helper,
          'source_repository' => @source.fetch('full_name', 'UNKNOWN'),
          'source_fork' => @source.fetch('fork', 'UNKNOWN'),
          'report_helper' => report_helper, 'startup_prompt' => prompt(skill, head) }
      end

      def prompt(skill, head)
        <<~PROMPT
          Use the explicitly selected Shaka trial skill at #{JSON.generate(skill)}.
          This task opts into #{@url} at #{head}; keep this exact helper for the whole task.
          Candidate source: #{JSON.generate(@source.fetch('full_name', 'UNKNOWN'))}.
          Fork source: #{JSON.generate(@source.fetch('fork', 'UNKNOWN'))}; this is explicitly selected experimental code.
          Work in #{JSON.generate(@root)}. Preserve the project's trusted settings and merge policy.
          In the resulting PR body, record #{@url} and this exact workflow commit URL:
          https://github.com/#{Reference::REPOSITORY}/commit/#{head}
          At completion, report what helped, corrections needed, and a keep/revise/drop verdict.
          For authorized feedback publication, use #{JSON.generate(report_helper)} trial report;
          read its packaged references/pr-trials.md for the report JSON format.
          Keep private project links and context out of public trial reports.
          The user's task is this JSON string: #{JSON.generate(@task)}
        PROMPT
      end

      def report_helper = File.realpath('../../../scripts/shaka', __dir__)

      def fetch(source, number)
        git(nil, 'init', '--quiet', source)
        git(source, 'remote', 'add', 'origin', 'https://github.com/shakacode/shaka.git')
        git(source, 'fetch', '--quiet', '--depth=1', 'origin', "refs/pull/#{number}/head")
        git(source, 'checkout', '--quiet', '--detach', 'FETCH_HEAD')
      end

      def git(directory, *)
        command = ['git', '-c', "core.hooksPath=#{File::NULL}", '-c', 'submodule.recurse=false']
        command.push('-C', directory) if directory
        output, error, status = Open3.capture3(GIT_ENV, *command, *)
        raise Error, "Trial source Git operation failed: #{error.strip}" unless status.success?

        output.strip
      end

      def project_root(root)
        output, _error, status = Open3.capture3('git', '-C', root, 'rev-parse', '--show-toplevel')
        File.realpath(status.success? ? output.strip : root)
      end

      def canonical(path)
        expanded = File.expand_path(path)
        ancestor = expanded
        ancestor = File.dirname(ancestor) until File.exist?(ancestor) || File.symlink?(ancestor)
        File.join(File.realpath(ancestor), expanded.delete_prefix(ancestor).delete_prefix('/'))
      end

      def refuse_overlap(path = @directory)
        return unless path == @root || path.start_with?("#{@root}/") ||
                      @root.start_with?("#{path}/")

        raise Error, 'Trial packages must be outside the target project checkout.'
      end
    end
  end
end
