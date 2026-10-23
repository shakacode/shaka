# frozen_string_literal: true

require 'open3'
require_relative '../error'

module Shaka
  # Self-hosted previews keep evidence verification installed and load only reviewed renderers.
  module RenderingPreview
    REPOSITORY = 'shakacode/shaka'
    DIRECTORY = 'skills/shaka/lib/shaka/publication/'
    RENDERERS = %w[usage_details metrics intent_verification publication].map { |name| "#{DIRECTORY}#{name}.rb" }.freeze
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

      sources = RENDERERS.to_h { |path| [path, git(root, 'show', "#{head}:#{path}")] }
      sources.each { |path, source| load_renderer(path, source) }
      "#{yield}\n<!-- shaka:rendering-preview #{head} -->\n"
    end

    # This check belongs to Shaka's own PRs, not to projects that use Shaka.
    def required?(github) = !changed_renderers(github).empty?

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
        paths.concat(files.map { |file| file.fetch('filename') }.select { |path| path.start_with?(DIRECTORY) })
        return paths if files.size < 100

        page += 1
      end
    end

    def current?(body, head) = body.to_s.scan(MARKER).flatten == [head]

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

    private_class_method :git, :load_renderer, :changed_renderers, :supported!
  end
end
