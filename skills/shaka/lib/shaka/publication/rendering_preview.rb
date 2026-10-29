# frozen_string_literal: true

require 'open3'
require_relative '../error'
require_relative '../publication_settings_guard'
require_relative '../rendering_load_order'

module Shaka
  # Self-hosted previews keep evidence verification, guards, and GitHub writes installed and load the other renderers.
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
    # Every other Ruby file directly in DIRECTORY previews from the head. These stay installed because they guard
    # the PR or run after its description renders, inside the GitHub write or a refusal of it: the loader, the
    # configuration and review-effort guards, the write with its region markers and rendering check, and the merge
    # warning and decisions check that follow rendering.
    INSTALLED = %w[rendering_preview feature_guard review_effort_floor publishing managed_region rendered_prose
                   merge_warning_region checkpoint_recommendation].map { |name| "#{DIRECTORY}#{name}.rb" }.freeze
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
      # The CLI loads every installed renderer; the head copies, stripped of requires, rely on their dependencies.
      installed_files.each { |path| require File.join(__dir__, File.basename(path)) }
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

    # Returns the changed files the preview keeps installed, so a handoff can say they were not previewed.
    def supported!(github)
      changed = changed_renderers(github)
      unsupported = changed.reject { |path| previewable?(path) }
      return changed & INSTALLED if unsupported.empty?

      raise Error, "Rendering preview does not yet load: #{unsupported.join(', ')}. " \
                   "It previews only the Ruby files directly in #{DIRECTORY}."
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

    def previewable?(path) = File.dirname(path) == DIRECTORY.chomp('/') && path.end_with?('.rb')

    # A head missing an installed renderer was not rebased, and a preview never stands in for a missing renderer.
    def sources(root, head)
      present = head_files(root, head)
      missing = installed_files - present
      raise Error, "Rendering preview refused: the PR head lacks #{missing.join(', ')}; rebase it." unless
        missing.empty?

      code = (present - INSTALLED).to_h { |path| [path, git(root, 'show', "#{head}:#{path}")] }
      RenderingLoadOrder.call(code, present, DIRECTORY).to_h { |path| [path, code.fetch(path)] }
    end

    def installed_files = Dir[File.join(__dir__, '*.rb')].map { |file| "#{DIRECTORY}#{File.basename(file)}" }

    def head_files(root, head)
      git(root, 'ls-tree', '-z', head, '--', DIRECTORY).split("\0").filter_map do |entry|
        mode, path = entry.split("\t", 2)
        path if mode.start_with?('100') && previewable?(path)
      end
    end

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

    private_class_method :git, :sources, :installed_files, :head_files, :load_renderers,
                         :load_renderer, :changed_renderers, :supported!, :previewable?, :rendering_path?
  end
end
