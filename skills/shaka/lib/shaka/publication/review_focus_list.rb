# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # Renders the few files or line ranges the implementer asks reviewers to read more closely than the rest, each
  # with its reason, under Risk and review. ReviewFocus finds their lines at the head.
  module ReviewFocusList
    # level is the retired 1-5 rating; an agent may still send it for a while, and it is ignored.
    FIELDS = %w[path level reason from to block].freeze
    SAFE_PATH = %r{\A[\w.@+/ -]+\z}
    LABEL = '**Flagged by the implementer:**'

    module_function

    # The pull's shaka_review_focus holds, in content order, each entry's head link and line range;
    # without it, paths render unlinked.
    def render(intent, pull = nil)
      resolved = pull&.dig('shaka_review_focus')
      listed = PublicationText.list(intent['review_focus'], 'intent review_focus')
      checked = listed.each_with_index.map { |entry, index| checked(entry, "review_focus #{index + 1}") }
      return [] if checked.empty?

      ["#{LABEL}\n#{checked.zip(Array(resolved)).map { |entry, link| line(entry, link) }.join("\n")}"]
    end

    def checked(entry, label)
      raise Error, "Publication intent #{label} must be an object." unless entry.is_a?(Hash)

      unknown = entry.keys - FIELDS
      raise Error, "Publication intent #{label} has unknown fields: #{unknown.join(', ')}." if unknown.any?

      path!(entry['path'], label)
      anchor!(entry, label)
      PublicationText.single_line(entry['reason'], "intent #{label} reason")
      entry
    end

    def path!(path, label)
      return if path.is_a?(String) && !path.start_with?('/') && !path.split('/', -1).intersect?(['', '.', '..'])

      raise Error, "Publication intent #{label} needs a repository-relative path."
    end

    # As in walkthrough code links: from starts a range, and to or block, never both, ends it.
    def anchor!(entry, label)
      range_end!(entry, label)
      return if entry['from'].nil? && !entry.key?('to') && !entry['block']
      return if text?(entry['from'])

      raise Error, "Publication intent #{label} needs from text to start its range."
    end

    def range_end!(entry, label)
      block = entry['block']
      raise Error, "Publication intent #{label} has a non-boolean block." unless [nil, true, false].include?(block)
      raise Error, "Publication intent #{label} takes either to or block, not both." if block && entry['to']
      raise Error, "Publication intent #{label} has invalid to text." if entry.key?('to') && !text?(entry['to'])
    end

    def text?(value) = value.is_a?(String) && !value.strip.empty?

    def line(entry, link)
      reason = PublicationText.single_line(entry['reason'], 'intent review_focus reason')
      "- #{target(entry['path'], link)}, #{reason}"
    end

    # A changed filename comes from the PR author, so only a plain one reaches the description;
    # its link keeps the path percent-encoded.
    def target(path, link)
      name = path.match?(SAFE_PATH) ? "`#{path}`" : 'a file whose name is withheld'
      return name unless link

      first, last = link['lines']
      span = if first.nil? then ''
             elsif first == last then " line #{first}"
             else " lines #{first}–#{last}"
             end
      "[#{name}#{span}](#{link['url']})"
    end

    private_class_method :checked, :path!, :anchor!, :range_end!, :text?, :line, :target
  end
end
