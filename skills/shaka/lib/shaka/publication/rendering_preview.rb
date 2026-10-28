# frozen_string_literal: true

require 'open3'
require_relative '../error'
require_relative '../publication_settings_guard'

module Shaka
  # Self-hosted previews keep evidence verification installed and load only reviewed renderers.
  module RenderingPreview
    REPOSITORY = 'shakacode/shaka'
    DIRECTORY = 'skills/shaka/lib/shaka/publication/'
    OTHER_RENDERERS = %w[walkthrough/ local_review/comment.rb local_review/comment_part.rb
                         local_review/loop_comment.rb local_review/history.rb local_review/triage_history.rb
                         local_review/summary.rb local_review/assessment_view.rb local_review/attention.rb
                         local_review/commit_section.rb local_review/usage.rb local_review/coverage.rb
                         local_review/bound.rb local_review/budget.rb local_review/fallback.rb local_review/triage.rb
                         local_review/publisher.rb
                         post_implementation/publication.rb post_implementation/execution_text.rb
                         post_implementation/adequacy.rb post_implementation/publisher_identity.rb
                         post_implementation/history.rb post_implementation/auto_merge_preview.rb
                         post_implementation/disposition.rb post_implementation/merge_warning.rb]
                      .map { |path| "skills/shaka/lib/shaka/#{path}" }.freeze
    # In load order: a renderer loads before the ones that call it.
    RENDERERS = %w[usage_details usage_pricing throughput_gate throughput_line throughput_stats metrics
                   verification_gates diff_buckets intent_verification task_source_line provenance
                   provenance_history settings_table settings publication]
                .map { |name| "#{DIRECTORY}#{name}.rb" }.freeze
    # A listed renderer the default branch does not have yet. A head without it keeps the installed copy;
    # every other listed renderer must be at the head, so a preview never stands in for a missing one.
    NOT_YET_LANDED = %w[task_source_line throughput_gate throughput_line throughput_stats]
                     .map { |name| "#{DIRECTORY}#{name}.rb" }.freeze
    MARKER = /<!-- shaka:rendering-preview ([0-9a-f]{40}) -->/

    module_function

    def publish(options, pull, github, &)
      root = options[:rendering_preview_root]
      return yield unless root
      unless pull.dig('head', 'repo', 'full_name').to_s.casecmp?(github.repository)
        raise Error, 'Rendering preview requires a same-repository PR.'
      end

      supported!(github)
      render(root:, head: pull.dig('head', 'sha'), repository: github.repository, &)
    end

    def render(root:, head:, repository:)
      raise Error, 'Rendering previews are only supported for shakacode/shaka.' unless repository.casecmp?(REPOSITORY)
      raise Error, 'Rendering preview needs a full commit SHA.' unless head.to_s.match?(/\A[0-9a-f]{40}\z/)
      raise Error, 'Rendering preview checkout does not name the live head.' unless git(root, 'rev-parse',
                                                                                        'HEAD').strip == head

      load_renderers(root, head)
      "#{yield}\n<!-- shaka:rendering-preview #{head} -->\n"
    end

    # Loading reopens PublicationSettings, so a head that redefines its evidence or policy methods is refused.
    def load_renderers(root, head)
      installed = PublicationSettingsGuard.snapshot
      sources(root, head).each { |path, source| load_renderer(path, source) }
      return unless PublicationSettingsGuard.changed?(installed)

      raise Error, 'Rendering preview refused: the PR head redefines settings verification or policy; ' \
                   'rebase it onto the default branch.'
    end

    # This check belongs to Shaka's own PRs, not to projects that use Shaka.
    def required?(github) = !changed_renderers(github).empty?

    # A description marker cannot attest to another artifact's rendering. Fail closed
    # until that renderer has a reviewed preview and artifact-specific evidence check.
    def verify_supported!(github) = supported!(github)

    def supported!(github)
      unsupported = changed_renderers(github) - RENDERERS - ["#{DIRECTORY}rendering_preview.rb"]
      return if unsupported.empty?

      raise Error, "Rendering preview does not yet load: #{unsupported.join(', ')}. Extend the reviewed renderer list."
    end

    def changed_renderers(github)
      return [] unless github.repository.casecmp?(REPOSITORY)

      page = 1
      paths = []
      loop do
        files = github.api_list("repos/#{github.repository}/pulls/#{github.number}/files?per_page=100&page=#{page}")
        paths.concat(files.map { |file| file.fetch('filename') }.select { |path| rendering_path?(path) })
        return paths if files.size < 100

        page += 1
      end
    end

    def current?(body, head) = body.to_s.scan(MARKER).flatten == [head]

    def invalidate(body) = body.to_s.gsub(MARKER, '')

    def rendering_path?(path)
      path.start_with?(DIRECTORY) || OTHER_RENDERERS.any? do |renderer|
        renderer.end_with?('/') ? path.start_with?(renderer) : path == renderer
      end
    end

    def sources(root, head)
      listed = RENDERERS.reject { |path| NOT_YET_LANDED.include?(path) && !present?(root, head, path) }
      listed.to_h { |path| [path, git(root, 'show', "#{head}:#{path}")] }
    end

    # A read failure raises, so only a path the head truly lacks counts as absent.
    def present?(root, head, path) = !git(root, 'ls-tree', '--name-only', head, '--', path).strip.empty?

    def git(root, *)
      output, error, status = Open3.capture3('git', '-C', root, *)
      raise Error, "Cannot read rendering preview: #{error.strip}" unless status.success?

      output
    end

    # Dependencies, evidence checks, and installation identity stay installed. Only these
    # class/module bodies come from the reviewed commit, never the candidate CLI or policy.
    def load_renderer(path, source)
      code = source.lines.map { |line| line.match?(/\Arequire(?:_relative)? /) ? "\n" : line }.join
      previous = $VERBOSE
      $VERBOSE = nil
      eval(code, TOPLEVEL_BINDING, path, 1) # rubocop:disable Security/Eval
    ensure
      $VERBOSE = previous
    end

    private_class_method :git, :sources, :present?, :load_renderers, :load_renderer, :changed_renderers, :supported!,
                         :rendering_path?
  end
end
