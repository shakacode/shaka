# frozen_string_literal: true

require 'open3'

# Chooses the test files a change can reach, for `bin/run-tests --changed`. A test reaches a
# Ruby file it loads through require or require_relative, directly or through other files. A
# test that starts the helper or a bin script also reaches every file that entry point loads.
# Any change it cannot map returns nil, which means the whole suite.
class ChangedTests
  LIBRARY = 'skills/shaka/lib/'
  # Changes here can affect every test, so they always run the whole suite.
  FOUNDATIONS = %w[test/test_helper.rb test/support/changed_tests.rb bin/run-tests Gemfile Gemfile.lock
                   .ruby-version].freeze
  # These tests read library sources as text instead of loading them.
  SOURCE_READERS = %w[test/configuration_boundary_test.rb test/install_refusal_wording_test.rb
                      test/rendering_preview_guard_test.rb test/rendering_preview_head_test.rb
                      test/evidence_relevant_code_test.rb].freeze
  # Text in a test or its support files that shows it starts an entry point in a child process.
  ENTRY_POINTS = {
    'skills/shaka/scripts/shaka.rb' => %r{shaka_command|SHAKA_COMMAND|scripts/shaka|scripts', 'shaka'},
    'bin/install' => %r{bin/install|'bin', 'install'},
    'bin/canary' => %r{bin/canary},
    'bin/report-instruction-growth' => /report-instruction-growth/
  }.freeze

  def initialize(root)
    @root = File.expand_path(root)
    @loads = {}
  end

  # Paths relative to the root, or nil for the whole suite.
  def tests_for(changes)
    return nil if changes.empty?

    changes.each_with_object([]) do |(status, path), selected|
      found = tests_for_path(status, path)
      return nil unless found

      selected.concat(found)
    end.uniq.sort
  end

  # Status letter and path for each file changed since BASE's merge base, including
  # uncommitted and untracked files.
  def changes(base)
    merge_base = git('merge-base', base, 'HEAD').strip
    listed = git('diff', '--no-ext-diff', '--no-renames', '--name-status', merge_base, '--')
    tracked = listed.lines.map { |line| line.chomp.split("\t", 2) }
    tracked + git('ls-files', '--others', '--exclude-standard').lines.map { ['A', it.chomp] }
  end

  private

  def tests_for_path(status, path)
    return nil unless mappable?(status, path)
    return [path] if map.key?(path)

    loaders = map.select { |_, files| files.include?(path) }.keys
    return nil if loaders.empty?

    path.start_with?(LIBRARY) ? loaders + (SOURCE_READERS & map.keys) : loaders
  end

  def mappable?(status, path) = %w[M A].include?(status) && path.end_with?('.rb') && !FOUNDATIONS.include?(path)

  def map
    @map ||= Dir.glob('test/**/*_test.rb', base: @root).to_h { |test| [test, reach(test)] }
  end

  def reach(test)
    files = loads(test)
    ENTRY_POINTS.each do |entry, marker|
      files |= loads(entry) if files.any? { |file| file.start_with?('test/') && starts?(file, marker) }
    end
    files
  end

  def starts?(file, marker)
    file != 'test/test_helper.rb' && read(file).match?(marker)
  end

  def loads(path)
    @loads[path] ||= begin
      seen = [path]
      seen.each { |file| requires(file).each { seen << it unless seen.include?(it) } }
      seen
    end
  end

  def requires(path)
    (@requires ||= {})[path] ||= required_paths(path)
  end

  def required_paths(path)
    source = read(path)
    relative = source.scan(/^\s*require_relative\s+['"]([^'"]+)['"]/).flatten.map do |name|
      File.join(File.dirname(path), name)
    end
    (relative + library_names(source)).map { normalize(it) }.select { File.file?(File.join(@root, it)) }
  end

  # A child Ruby started with -rshaka/NAME loads that library file too.
  def library_names(source)
    source.scan(%r{^\s*require\s+['"](shaka/[^'"]+)['"]|['"]-r(shaka/[^'"]+)['"]}).flatten.compact
          .map { File.join(LIBRARY, it) }
  end

  def normalize(name)
    name = "#{name}.rb" unless name.end_with?('.rb') || File.file?(File.join(@root, name))
    File.expand_path(name, @root).delete_prefix("#{@root}/")
  end

  def read(path) = File.read(File.join(@root, path), encoding: 'UTF-8')

  def git(*args)
    output, status = Open3.capture2('git', '-C', @root, *args)
    raise "git #{args.first} failed" unless status.success?

    output
  end
end
