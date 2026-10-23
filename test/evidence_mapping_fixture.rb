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
    File.write(File.join(root, 'script/selector.rb'), "exit(ARGV == #{MAPPINGS.inspect} ? 0 : 64)\n")
    File.write(File.join(root, 'script/security.rb'), "exit 0\n")
    mappings = fixed ? MAPPINGS.shelljoin : '"$@"'
    File.write(File.join(root, '.agents/bin/validate'), <<~SH)
      #!/bin/sh
      set -eu
      ruby script/selector.rb #{mappings}
      ruby script/security.rb
    SH
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
