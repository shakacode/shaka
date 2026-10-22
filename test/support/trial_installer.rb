# frozen_string_literal: true

# Install tests copy this to a fixture checkout's bin/trial-install. It drives the installer PR trials use,
# linking into --skills-dir so tests can inspect the packaged copy.
invoked_root = File.expand_path('..', File.dirname($PROGRAM_NAME))
resolved_root = File.expand_path('..', __dir__)
source_root = File.realpath(invoked_root) == resolved_root ? invoked_root : resolved_root
require File.join(resolved_root, 'skills/shaka/lib/shaka/installer')

TOWERS = { '--with-rct' => ['rct'], '--with-mct' => ['mct'],
           '--with-claude-towers' => %w[mct-claude rct-claude] }.freeze
options = { names: ['shaka'], managed_dir: File.join(Dir.home, '.local/share/shaka/installs') }
arguments = ARGV.dup
until arguments.empty?
  case (flag = arguments.shift)
  when '--skills-dir' then options[:skills_dir] = arguments.shift
  when '--managed-dir' then options[:managed_dir] = arguments.shift
  else options[:names].concat(TOWERS.fetch(flag) { abort "Unknown flag: #{flag}" })
  end
end

abort 'Missing --skills-dir' if options[:skills_dir].to_s.strip.empty?

begin
  puts "Package: #{File.basename(Shaka::Installer.new(source_root:, **options).run)}"
rescue SystemCallError, IOError, ArgumentError => e
  warn e.message
  exit 1
end
