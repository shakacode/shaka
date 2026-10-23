# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shellwords'

module EvidenceMappingFixture
  include EvidenceFixture

  MAPPINGS = ['--spec-for', 'app/new.rb', 'spec/new_spec.rb',
              '--no-spec-for', 'README.md', 'documentation only'].freeze

  private

  def with_mapping_checkout(fixed: false)
    with_checkout do |root, _ref|
      write_mapping_commands(root, fixed:)
      yield root, commit_changes(root)
    end
  end

  def write_mapping_commands(root, fixed:)
    FileUtils.mkdir_p(File.join(root, 'script'))
    write_mapping_selector(root)
    File.write(File.join(root, 'script/security.rb'), "exit 0\n")
    mappings = fixed ? MAPPINGS.shelljoin : '"$@"'
    File.write(File.join(root, '.agents/bin/validate'), <<~SH)
      #!/bin/sh
      set -eu
      ruby script/selector.rb #{mappings}
      ruby script/security.rb
    SH
  end

  def write_mapping_selector(root)
    File.write(File.join(root, 'changed-files.json'), JSON.generate(['app/new.rb', 'README.md']))
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

  def supply_default_mappings(root)
    path = File.join(root, 'script/selector.rb')
    File.write(path, "ARGV.replace(#{MAPPINGS.inspect}) if ARGV.empty?\n" + File.read(path))
  end
end
