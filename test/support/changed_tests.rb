# frozen_string_literal: true

require 'open3'
require 'stringio'

# Chooses the test files a change can reach, for `bin/run-tests --changed`. A test reaches a
# Ruby file it loads through require or require_relative, directly or through other files. A
# test that starts the helper or a bin script also reaches every file that entry point loads.
# A deleted Ruby file maps to the tests that reached it at the base. A Markdown, YAML, or JSON
# file in a place DATA_PLACES lists, or a figure under docs/img/, maps to the tests whose own
# test files name it; when none does, the change runs no tests. Any other change it cannot map
# returns nil, which means the whole suite.
class ChangedTests
  LIBRARY = 'skills/shaka/lib/'
  # Changes here can affect every test, so they always run the whole suite.
  FOUNDATIONS = %w[test/test_helper.rb test/support/changed_tests.rb bin/run-tests test/support/worker_plan.rb
                   Gemfile Gemfile.lock .ruby-version].freeze
  # These tests read library sources as text, or load renderers the preview requires at runtime.
  SOURCE_READERS = %w[test/configuration_boundary_test.rb test/install_refusal_wording_test.rb
                      test/rendering_preview_guard_test.rb test/rendering_preview_head_test.rb
                      test/rendering_preview_test.rb test/evidence_relevant_code_test.rb].freeze
  # Text in a test or its support files that shows it starts an entry point in a child process.
  ENTRY_POINTS = {
    'skills/shaka/scripts/shaka.rb' => %r{shaka_command|SHAKA_COMMAND|scripts/shaka|scripts', 'shaka'},
    'bin/install' => %r{bin/install|'bin', 'install'},
    'bin/canary' => %r{bin/canary},
    'bin/report-instruction-growth' => /report-instruction-growth/
  }.freeze
  DATA = /\.(?:md|ya?ml|json)\z/
  # Places whose Markdown, YAML, and JSON files tests read only by naming them. A key ending in /
  # covers a directory. Skill and settings files stay out: tests reach them through the helper,
  # installs, and globs, so nearly every test reads them anyway.
  DATA_PLACES = %w[docs/ internal/ contributing/ README.md CHANGELOG.md CONTRIBUTING.md].freeze
  # Tests read figures only by naming them; bin/check-docs-navigation, which every validation runs, parses them all.
  FIGURES = 'docs/img/'

  attr_reader :files

  # REVISION reads the files of that commit instead of the working tree.
  def initialize(root, revision: nil)
    @root = File.expand_path(root)
    @files = Files.new(@root, revision, ENTRY_POINTS.keys)
    @loads = {}
  end

  # Paths relative to the root, or nil for the whole suite. BASE, the merge base, maps deletions.
  def tests_for(changes, base: nil)
    return nil if changes.empty?

    changes.each_with_object([]) do |(status, path), selected|
      found = tests_for_path(status, path, base)
      return nil unless found

      selected.concat(found)
    end.uniq.sort
  end

  # Tests that reach the Ruby file PATH, or nil when none does.
  def code_readers(path)
    # A test reaches itself, and other tests may require it for its fixtures.
    loaders = map.select { |_, files| files.include?(path) }.keys
    return nil if loaders.empty?

    path.start_with?(LIBRARY) ? loaders + (SOURCE_READERS & map.keys) : loaders
  end

  private

  def tests_for_path(status, path, base)
    return nil if FOUNDATIONS.include?(path) || !%w[M A D].include?(status)
    return data_readers(path) unless path.end_with?('.rb')
    return code_readers(path) unless status == 'D'

    base && deleted_readers(path, base)
  end

  # Tests that no longer exist cannot run.
  def deleted_readers(path, base)
    found = (@base ||= ChangedTests.new(@root, revision: base)).code_readers(path)
    found && (found & map.keys)
  end

  # A file names a data file by its last two path segments, such as docs/settings.md. Only files
  # under test/ count: library and bin files name these pages in links and comments, and the
  # packaged skill cannot read them, so counting those files would select most of the suite.
  def data_readers(path)
    return nil unless page?(path)

    name = path.split('/').last(2).join('/')
    reads = Hash.new { |known, file| known[file] = file.start_with?('test/') && names?(file, name) }
    map.select { |_, files| files.any? { reads[it] } }.keys
  end

  def page?(path)
    (path.match?(DATA) || path.start_with?(FIGURES)) &&
      DATA_PLACES.any? { it.end_with?('/') ? path.start_with?(it) : path == it }
  end

  def names?(file, name) = @files.file?(file) && @files.read(file).include?(name)

  def map
    @map ||= @files.tests.to_h { |test| [test, reach(test)] }
  end

  def reach(test)
    files = loads(test)
    ENTRY_POINTS.each do |entry, marker|
      files |= loads(entry) if files.any? { |file| file.start_with?('test/') && starts?(file, marker) }
    end
    files
  end

  def starts?(file, marker) = file != 'test/test_helper.rb' && @files.read(file).match?(marker)

  def loads(path)
    @loads[path] ||= begin
      seen = [path]
      seen.each { |file| requires(file).each { seen << it unless seen.include?(it) } }
      seen
    end
  end

  def requires(path) = (@requires ||= {})[path] ||= required_paths(path)

  def required_paths(path)
    return [] unless @files.file?(path)

    source = @files.read(path)
    relative = source.scan(/^\s*require_relative\s+['"]([^'"]+)['"]/).flatten.map do |name|
      File.join(File.dirname(path), name)
    end
    (relative + library_names(source)).map { normalize(it) }.select { @files.file?(it) }
  end

  # A child Ruby started with -rshaka/NAME loads that library file too.
  def library_names(source)
    source.scan(%r{^\s*require\s+['"](shaka/[^'"]+)['"]|['"]-r(shaka/[^'"]+)['"]}).flatten.compact
          .map { File.join(LIBRARY, it) }
  end

  def normalize(name)
    path = File.expand_path(name, @root).delete_prefix("#{@root}/")
    path.end_with?('.rb') || @files.file?(path) ? path : "#{path}.rb"
  end
end

class ChangedTests
  # Lists and reads the files of the working tree, or of one commit when REVISION is given.
  class Files
    def initialize(root, revision, entry_points)
      @root = root
      @revision = revision
      @entry_points = entry_points
    end

    def tests = @revision ? paths.grep(%r{\Atest/.*_test\.rb\z}) : Dir.glob('test/**/*_test.rb', base: @root)

    def file?(path) = @revision ? paths.include?(path) : File.file?(File.join(@root, path))

    def read(path)
      return File.read(File.join(@root, path), encoding: 'UTF-8') unless @revision

      blobs.fetch(path) { git('cat-file', 'blob', "#{@revision}:#{path}") }
    end

    # Status letter and path for each file changed since BASE's merge base, including
    # uncommitted and untracked files.
    def changes(base)
      # -z lists names as they are; line output quotes names with unusual characters.
      listed = git('diff', '--no-ext-diff', '--no-renames', '--name-status', '-z', merge_base(base), '--')
      listed.split("\0").each_slice(2).to_a +
        git('ls-files', '--others', '--exclude-standard', '-z').split("\0").map { ['A', it] }
    end

    def merge_base(base) = git('merge-base', base, 'HEAD').strip

    def git(*args, input: nil)
      output, status = Open3.capture2('git', '-C', @root, *args, stdin_data: input, binmode: true)
      raise "git #{args.first} failed" unless status.success?

      output.force_encoding('UTF-8')
    end

    private

    def paths
      @paths ||= git('ls-tree', '-r', '-z', '--name-only', @revision).split("\0").to_set
    end

    # One git process reads every Ruby file and entry point of the revision.
    def blobs
      @blobs ||= begin
        # The batch reads one name per line, so a name holding a newline is read on its own.
        wanted = paths.select { (it.end_with?('.rb') || @entry_points.include?(it)) && !it.include?("\n") }
        stream = StringIO.new(git('cat-file', '--batch', input: wanted.map { "#{@revision}:#{it}\n" }.join))
        wanted.to_h { [it, blob(stream)] }
      end
    end

    # Each object is a header line ending in its size, the content, and a newline.
    def blob(stream)
      content = stream.read(Integer(stream.gets.split.fetch(2)))
      stream.read(1)
      content.force_encoding('UTF-8')
    end
  end
end
