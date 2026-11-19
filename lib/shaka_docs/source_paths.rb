# frozen_string_literal: true

require 'uri'
require 'addressable/uri'

module ShakaDocs
  # Resolve supported source citations without mistaking a file path for repository ownership.
  module SourcePaths
    module_function

    def url(target)
      text = target.delete("\t\r\n").gsub(/\A[\x00-\x20]+|[\x00-\x20]+\z/, '')
      text = text.tr('\\', '/').sub(%r{\A(https?:)?/{3,}}i, '\1//')
      uri = Addressable::URI.parse(text)
      if %w[http https].include?(uri.scheme&.downcase) && uri.host.to_s.empty?
        raise ArgumentError, "HTTP(S) links must use ://host: #{target}"
      end

      uri.host ? uri.normalize : uri
    end

    def repository_path(uri)
      host = uri.host.to_s.delete_prefix('www.')
      return cdn_repository_path(uri) unless %w[github.com raw.githubusercontent.com].include?(host)

      source = URI::DEFAULT_PARSER.unescape(uri.path)[%r{\A/shakacode/shaka/(.*)\z}i, 1]
      return unless source

      # Source citations use a commit, tag, or single-segment branch. Do not infer
      # a repository root from a directory name inside the document path.
      if host == 'github.com'
        source = source.sub!(%r{\A(?:blob|tree|raw|edit|blame)/}, '')
        return unless source
      end
      source.sub(%r{\Arefs/(?:heads|tags)/}, '').split('/', 2)[1]
    end

    def cdn_repository_path(uri)
      return unless uri.host == 'cdn.jsdelivr.net'

      URI::DEFAULT_PARSER.unescape(uri.path.to_s)[
        %r{\A/gh/(?i:shakacode/shaka)(?:@[^/]+)?/(.*)\z}, 1
      ]
    end

    def local_path(repository, source, target)
      uri = url(target)
      return legacy_reference_path(repository_path(uri)) if uri.scheme || uri.host

      target = URI::DEFAULT_PARSER.unescape(uri.path)
      return "docs#{target}" if target.start_with?('/')

      File.absolute_path(target, File.dirname(source)).delete_prefix("#{repository}/")
    end

    def legacy_reference_path(path)
      path&.sub(%r{\A.+/(skills/shaka/references(?:/.*)?\z)}, '\\1')
    end
  end
end
