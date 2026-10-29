# frozen_string_literal: true

require 'pathname'
require_relative 'error'

module Shaka
  # Orders a rendering preview's head files so each loads after the sibling files it requires, and a callee is
  # defined before its caller's body runs. It lives outside the previewed directory, so a head cannot replace it.
  module RenderingLoadOrder
    # The preview blanks these lines before evaluating a head file, so the order and the stripping agree.
    REQUIRE = /\Arequire(?:_relative)?\s/
    SIBLING = /\Arequire_relative\s+(['"])([^'"]+)\1\s*\z/

    module_function

    # `code` maps each file to load to its source; `present` lists every file in `directory` at the head.
    def call(code, present, directory)
      order = []
      code.keys.sort.each { |path| visit(path, code, [present, directory], order, []) }
      order
    end

    def visit(path, code, head, order, trail)
      raise Error, "Rendering preview refused: require_relative cycle #{[*trail, path].join(' -> ')}." if
        trail.include?(path)
      return if order.include?(path) || !code.key?(path)

      siblings(path, code.fetch(path), *head).each { |callee| visit(callee, code, head, order, [*trail, path]) }
      order << path
    end

    # Requires outside the directory stay installed. A sibling the head lacks would leave its caller undefined.
    def siblings(path, source, present, directory)
      names(path, source).filter_map do |name|
        sibling = Pathname(File.dirname(path)).join("#{name.delete_suffix('.rb')}.rb").cleanpath.to_s
        next unless File.dirname(sibling) == directory.chomp('/')
        raise Error, "Rendering preview refused: #{path} requires #{sibling}, absent at the head." unless
          present.include?(sibling)

        sibling
      end.sort
    end

    # Any other require_relative form would run unstripped, or go unordered, so it is refused.
    def names(path, source)
      source.lines.filter_map do |line|
        next unless line.match?(/\A\s*require_relative\b/)

        line[SIBLING, 2] || raise(Error, "Rendering preview refused: #{path} has a require_relative it cannot order: " \
                                         "#{line.strip}. Write require_relative 'name' at the start of a line.")
      end
    end

    private_class_method :visit, :siblings, :names
  end
end
