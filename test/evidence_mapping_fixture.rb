# frozen_string_literal: true

require_relative 'evidence_fixture'

module EvidenceMappingFixture
  include EvidenceFixture

  MAPPINGS = ['--spec-for', 'app/new.rb', 'spec/new_spec.rb'].freeze
  DURABLE_SELECTOR = <<~RUBY_SCRIPT
    require 'json'
    JSON.parse(File.read('changed-files.json')).each do |path|
      case path
      when 'app/new.rb'
        puts 'spec/new_spec.rb'
      else
        exit 64
      end
    end
  RUBY_SCRIPT

  private

  def with_mapping_checkout
    with_checkout do |root, _ref|
      write_mapping_commands(root)
      yield root, commit_changes(root)
    end
  end

  def write_mapping_commands(root)
    FileUtils.mkdir_p(File.join(root, 'script'))
    write_mapping_selector(root)
    File.write(File.join(root, '.agents/shaka/bin/validate'), "#!/bin/sh\nset -eu\nruby script/selector.rb \"$@\"\n")
  end

  def write_mapping_selector(root)
    File.write(File.join(root, 'changed-files.json'), JSON.generate(['app/new.rb']))
    File.write(File.join(root, 'script/selector.rb'), <<~RUBY_SCRIPT)
      require 'json'
      changed = JSON.parse(File.read('changed-files.json'))
      mapped = ARGV.each_slice(3).map { |_kind, path, _value| path }
      exit(ARGV == #{MAPPINGS.inspect} && (changed - mapped).empty? ? 0 : 64)
    RUBY_SCRIPT
  end

  def commit_changes(root)
    git(root, 'add', '-A')
    commit(root)
    git(root, 'rev-parse', 'HEAD')
  end

  def supply_durable_selector_rules(root)
    File.write(File.join(root, 'script/selector.rb'), DURABLE_SELECTOR)
  end
end
