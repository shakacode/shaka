# frozen_string_literal: true

# Loading this file checks the running Ruby, so an older Ruby stops with a fix before it
# parses code written for Ruby 3.4. Keep it parseable by any Ruby. The launcher preloads
# it with -r, and a symlinked skill path can load it twice, so a second load does nothing.
return if defined?(Shaka::RubyRequirement)

module Shaka
  # Names the Ruby Shaka needs and stops an older one.
  module RubyRequirement
    MINIMUM = '3.4'
    GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/getting-started.md#1-install-shaka'
    # The package around this skill: a source checkout has bin/install, and an installed one has its record.
    PACKAGE = File.expand_path('../../../..', __dir__)
    INSTALLED = ['bin/install', '.shaka-install.json', '.git/shaka-install.json'].freeze

    def self.check!(version = RUBY_VERSION)
      return if (version.split('.').map(&:to_i) <=> MINIMUM.split('.').map(&:to_i)) >= 0

      # Kernel#warn is silent under -W0, and this message is the only guidance an old Ruby gets.
      $stderr.write "Shaka needs Ruby #{MINIMUM} or newer; this Ruby is #{version}. #{remedy}\n"
      exit 1
    end

    # A skill copied without the installer has no installer to rerun, and its launcher used PATH.
    def self.remedy
      if INSTALLED.any? { |path| File.exist?(File.join(PACKAGE, path)) }
        return "Rerun bin/install with Ruby #{MINIMUM}, or set SHAKA_RUBY to a Ruby #{MINIMUM} interpreter."
      end

      'This copy of Shaka was not set up by its installer, so it ran the first ruby on PATH, which the ' \
        "current project or system selects. Install Shaka with the official installer (#{GUIDE}), " \
        "which records its own Ruby, or set SHAKA_RUBY to a Ruby #{MINIMUM} interpreter."
    end
  end
end

Shaka::RubyRequirement.check!
