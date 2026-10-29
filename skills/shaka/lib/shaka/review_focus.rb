# frozen_string_literal: true

require 'uri'
require_relative 'error'
require_relative 'walkthrough/code_links'

module Shaka
  # Finds the head lines each intent review_focus entry names, so the description links them at
  # the commit it describes. Reading lives here, outside publication/, which only renders.
  module ReviewFocus
    module_function

    # Returns one { url, lines } per entry in content order, or nil when there is no well-formed
    # list for ReviewFocusList to refuse first. pull carries the head and its complete file list.
    def resolve(content, github, pull)
      entries = content.dig('intent', 'review_focus')
      return unless entries.is_a?(Array) && !entries.empty? && entries.all?(Hash)

      head = pull.dig('head', 'sha')
      links = Walkthrough::CodeLinks.new({}, github, head)
      present = present_paths(pull.fetch('shaka_changed_files'))
      blob = "https://github.com/#{github.repository}/blob/#{head}/"
      entries.each_with_index.map do |entry, index|
        located(links, entry, "review_focus #{index + 1}", present, blob)
      end
    end

    # A removed file and the old name of a rename have no file at the head.
    def present_paths(files) = files.reject { |file| file['status'] == 'removed' }.map { |file| file['filename'] }

    def located(links, entry, label, present, blob)
      path = entry['path']
      unless present.include?(path)
        raise Error, "Publication intent #{label}: #{path} is not present at the head among this PR's changed files."
      end
      return { 'url' => blob + encoded(path), 'lines' => nil } if entry['from'].nil?

      first, last = links.locate(label, entry)
      anchor = first == last ? "#L#{first}" : "#L#{first}-L#{last}"
      { 'url' => "#{blob}#{encoded(path)}#{anchor}", 'lines' => [first, last] }
    rescue Error => e
      raise Error, e.message.sub(/\AWalkthrough #{label}/, "Publication intent #{label}")
    end

    # Encoded per segment, as walkthrough code links write it; walkthrough/ stays unchanged so the
    # description's rendering preview can still load.
    def encoded(path) = path.split('/').map { |segment| URI.encode_uri_component(segment) }.join('/')

    private_class_method :present_paths, :located, :encoded
  end
end
