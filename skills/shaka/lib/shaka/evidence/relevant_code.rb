# frozen_string_literal: true

require 'digest'
require_relative '../configuration/fingerprint/canonical'

module Shaka
  module Evidence
    # The installed files that decide how validation and review run and how their results are
    # checked. A result stays bound through any update that leaves these files alone. Rendering
    # code only shows results, and most settings code reaches them through its fingerprinted output.
    # The settings code listed here is the exception: the review runner reads it directly,
    # configuration.rb and sources.rb produce the prompt text a reviewer receives, and paths.rb names
    # the command directory whose absence makes a run use the trusted copy.
    # The built-in defaults count because the review runner reads its timeouts from them directly, and
    # the rate card because reviewer settings read their model names from it. The launcher picks the Ruby
    # that runs everything, and subcommands.rb routes `evidence` and `review` to their code.
    # The review folder counts whole, comment rendering included: listing those files apart would
    # have spared 3 of 315 commits on main.
    module RelevantCode
      ROOT = File.expand_path('../../..', __dir__)
      PATTERNS = %w[
        config/defaults.yml
        config/model-rates.yml
        config/review-prompt.md
        config/review-instructions-precedence.md
        lib/shaka/evidence/*.rb
        lib/shaka/local_review.rb
        lib/shaka/local_review/*.rb
        lib/shaka/configuration/fingerprint.rb
        lib/shaka/configuration/fingerprint/*.rb
        lib/shaka/{call_log,defaults,error,pr_template,prompt_section,repository_identity}.rb
        lib/shaka/{review_prompt,reviewer_selection,reviewer_settings,subcommands,version,workflow_version}.rb
        lib/shaka/repository_config/{post_implementation_schema,prompt_files,review_limit,review_schema}.rb
        lib/shaka/configuration.rb
        lib/shaka/configuration/machine_reviewers.rb
        lib/shaka/configuration/paths.rb
        lib/shaka/configuration/sources.rb
        lib/shaka/doctor/cli_inventory.rb
        lib/shaka/usage/rate_card.rb
        scripts/shaka
      ].freeze

      module_function

      # The version and install kind still bind, so a release is a boundary for earlier results.
      def identity(installation)
        installation.slice('schema_version', 'version')
                    .merge('source' => { 'kind' => installation.dig('source', 'kind'), 'relevant_code' => digest })
      end

      def digest(root: ROOT)
        hashes = files(root).to_h { |path| [path, Digest::SHA256.file(File.join(root, path)).hexdigest] }
        Configuration::FingerprintCanonical.digest('relevant-code', hashes)
      end

      def files(root = ROOT) = PATTERNS.flat_map { |pattern| Dir.glob(pattern, base: root) }.uniq.sort
    end
  end
end
