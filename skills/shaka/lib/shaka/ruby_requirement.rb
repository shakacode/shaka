# frozen_string_literal: true

module Shaka
  # Stops an older Ruby with a fix before it reaches code written for Ruby 3.4.
  # Keep this file loadable by any Ruby: the entry points require it before anything else.
  module RubyRequirement
    MINIMUM = '3.4'

    def self.check!(version = RUBY_VERSION)
      return if (version.split('.').map(&:to_i) <=> MINIMUM.split('.').map(&:to_i)) >= 0

      # Kernel#warn is silent under -W0, and this message is the only guidance an old Ruby gets.
      $stderr.write "Shaka needs Ruby #{MINIMUM} or newer; this Ruby is #{version}. " \
                    "Rerun bin/install with Ruby #{MINIMUM}, or set SHAKA_RUBY to a Ruby #{MINIMUM} interpreter.\n"
      exit 1
    end
  end
end
