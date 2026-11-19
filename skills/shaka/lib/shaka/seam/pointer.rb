# frozen_string_literal: true

require 'optparse'
require_relative 'initializer_readme'
require_relative '../packaged_text'

module Shaka
  class Seam
    # Copy-ready AGENTS.md guidance, or with --readme the .agents/shaka.md that init writes.
    # Read-only: it writes nothing and loads no policy.
    module Pointer
      def self.text
        PackagedText.render('seam-pointer.md')
      end

      def self.emit(readme: false)
        puts readme ? InitializerReadme.text : text
        0
      end

      def self.refuse_foreign_options(options)
        return if options.except(:readme).empty?

        raise OptionParser::InvalidArgument, 'check and init options do not apply to pointer'
      end
    end
  end
end
