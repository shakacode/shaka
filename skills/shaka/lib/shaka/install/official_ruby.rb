# frozen_string_literal: true

require 'rbconfig'

module Shaka
  module Install
    # Records the Ruby that installed the checkout, so the helper ignores project Ruby settings.
    module OfficialRuby
      RUBY_RECORD = 'shaka-ruby'

      private

      def record_ruby
        path = File.join(@checkout.root, '.git', RUBY_RECORD)
        temporary = "#{path}.#{Process.pid}"
        File.write(temporary, "#{File.realpath(RbConfig.ruby)}\n", mode: 'wx', perm: 0o600)
        File.rename(temporary, path)
      ensure
        File.unlink(temporary) if temporary && File.exist?(temporary)
      end

      def verify_ruby
        ruby = File.read(File.join(@checkout.root, '.git', RUBY_RECORD)).strip
        raise ArgumentError, 'Installation Ruby is unavailable; rerun bin/install with Ruby 3.4' unless
          File.executable?(ruby)
      end
    end
  end
end
