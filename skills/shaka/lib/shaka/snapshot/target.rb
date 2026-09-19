# frozen_string_literal: true

require_relative '../error'
require_relative 'bytes'

module Shaka
  class Snapshot
    # Resolves where a push would actually land.
    #
    # A remote may push somewhere other than it fetches, so everything this command asks and
    # every lease it takes must name the repository that will receive the push rather than
    # the one it reads from. A name carrying several push URLs cannot be held by one lease,
    # so that configuration refuses rather than publishing under a lease that fits one of
    # them. A name with no configuration behind it is already a URL or a path.
    class Target
      def self.resolve(remote:, git:) = new(remote:, git:).resolve

      def initialize(remote:, git:)
        @remote = remote
        @git = git
      end

      def resolve
        urls = push_urls
        raise Error, "#{@remote} pushes to several URLs; snapshots refuse." if urls.length > 1

        urls.first || @remote
      end

      private

      def push_urls
        listed = @git.call('remote', 'get-url', '--push', '--all', @remote)
        Bytes.split(listed, "\n").reject { |url| url.b.strip.empty? }
      rescue Error
        []
      end
    end
  end
end
