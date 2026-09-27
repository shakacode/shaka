# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/code_links'

module CodeLinksFixtures
  HEAD = 'a' * 40
  BLOB = "https://github.com/owner/repo/blob/#{HEAD}".freeze
  PACKAGE = <<~RUBY
    class Package
      def prepare(root)
        stage(root)
      end

      def stage(root)
        copy(root)
        publish(root)
      end

      def publish(root)
        rename(root)
      end
    end
  RUBY
  SCRIPT = <<~PYTHON
    def first():
        return 1

    def second():
        return 2
  PYTHON

  FakeGitHub = Struct.new(:files, :requests) do
    def repository = 'owner/repo'

    def api(path, **)
      requests << path
      name = path[%r{/contents/(.+)\?ref=}, 1]
      raise Shaka::Error, "gh api #{path} failed (exit 1)." unless files.key?(name)

      { 'type' => 'file', 'encoding' => 'base64', 'content' => [files.fetch(name)].pack('m') }
    end
  end

  def github(files = { 'lib/package.rb' => PACKAGE, 'bin/tool.py' => SCRIPT })
    FakeGitHub.new(files, [])
  end

  def content(links, body)
    { 'head' => HEAD, 'summary' => 'Summary.', 'code_links' => links,
      'sections' => [{ 'heading' => 'Change', 'body' => body }] }
  end

  def resolved_body(links, body, client = github)
    Shaka::CodeLinks.resolve(content(links, body), client).fetch('sections').first.fetch('body')
  end
end

class CodeLinksTest < Minitest::Test
  include CodeLinksFixtures

  def test_block_link_covers_a_method_through_its_closing_line
    body = resolved_body({ 'stage' => { 'path' => 'lib/package.rb', 'from' => 'def stage', 'block' => true } },
                         'See [`stage`](code:stage).')
    assert_equal "See [`stage`](#{BLOB}/lib/package.rb#L6-L9).", body
  end

  def test_block_link_stops_before_the_next_definition_without_a_closer
    body = resolved_body({ 'first' => { 'path' => 'bin/tool.py', 'from' => 'def first', 'block' => true } },
                         '[first](code:first)')
    assert_equal "[first](#{BLOB}/bin/tool.py#L1-L2)", body
  end

  def test_to_link_ends_at_the_first_matching_line_after_from
    body = resolved_body({ 'flow' => { 'path' => 'lib/package.rb', 'from' => 'def stage', 'to' => 'rename' } },
                         '[flow](code:flow)')
    assert_equal "[flow](#{BLOB}/lib/package.rb#L6-L12)", body
  end

  def test_to_text_on_the_starting_line_does_not_end_the_range
    body = resolved_body({ 'x' => { 'path' => 'lib/package.rb', 'from' => 'def prepare', 'to' => 'end' } },
                         '[x](code:x)', github('lib/package.rb' => PACKAGE.sub('prepare(root)', 'prepare(send_end)')))
    assert_equal "[x](#{BLOB}/lib/package.rb#L2-L4)", body
  end

  def test_block_link_continues_past_a_multiline_signature
    source = "def call(\n  root\n)\n  run(root)\nend\n"
    body = resolved_body({ 'x' => { 'path' => 'lib/call.rb', 'from' => 'def call', 'block' => true } },
                         '[x](code:x)', github('lib/call.rb' => source))
    assert_equal "[x](#{BLOB}/lib/call.rb#L1-L5)", body
  end

  def test_link_without_to_or_block_names_one_line
    body = resolved_body({ 'call' => { 'path' => 'lib/package.rb', 'from' => 'copy(root)' } }, '[call](code:call)')
    assert_equal "[call](#{BLOB}/lib/package.rb#L7)", body
  end

  def test_links_resolve_in_summary_and_every_section_and_fetch_each_file_once
    client = github
    links = { 'stage' => { 'path' => 'lib/package.rb', 'from' => 'def stage', 'block' => true },
              'publish' => { 'path' => 'lib/package.rb', 'from' => 'def publish', 'block' => true } }
    resolved = Shaka::CodeLinks.resolve(content(links, '[a](code:stage) and [b](code:publish)')
                                          .merge('summary' => 'Start at [stage](code:stage).'), client)
    assert_equal "Start at [stage](#{BLOB}/lib/package.rb#L6-L9).", resolved['summary']
    assert_includes resolved['sections'].first['body'], "#{BLOB}/lib/package.rb#L11-L13"
    refute resolved.key?('code_links')
    assert_equal ["repos/owner/repo/contents/lib/package.rb?ref=#{HEAD}"], client.requests
  end

  def test_content_without_code_links_is_unchanged
    plain = { 'head' => HEAD, 'summary' => 'Summary.' }
    assert_same plain, Shaka::CodeLinks.resolve(plain, github)
  end
end

class CodeLinksRefusalTest < Minitest::Test
  include CodeLinksFixtures

  def test_ambiguous_or_missing_text_refuses_publication
    cases = {
      { 'path' => 'lib/package.rb', 'from' => 'def ' } => 'matches 3 lines',
      { 'path' => 'lib/package.rb', 'from' => 'def absent' } => 'matches 0 lines',
      { 'path' => 'lib/package.rb', 'from' => 'def publish', 'to' => 'def stage' } => 'no line after'
    }
    cases.each do |link, message|
      error = assert_raises(Shaka::Error) { resolved_body({ 'x' => link }, '[x](code:x)') }
      assert_includes error.message, message
      assert_includes error.message, 'code link x'
    end
  end

  def test_undefined_reference_and_invalid_definitions_are_refused
    link = { 'path' => 'lib/package.rb', 'from' => 'def stage' }
    [[{ 'x' => link }, '[y](code:y)', 'undefined code link y'],
     [{ 'x' => link.merge('to' => 'end', 'block' => true) }, '[x](code:x)', 'either to or block'],
     [{ 'x' => link.merge('path' => '../secret') }, '[x](code:x)', 'repository-relative path'],
     [{ 'x' => { 'path' => 'lib/package.rb' } }, '[x](code:x)', 'from text'],
     [[], '[x](code:x)', 'code_links must be an object']].each do |links, body, message|
      error = assert_raises(Shaka::Error) { resolved_body(links, body) }
      assert_includes error.message, message
    end
  end

  def test_unreadable_file_names_the_link
    error = assert_raises(Shaka::Error) do
      resolved_body({ 'x' => { 'path' => 'lib/missing.rb', 'from' => 'def x' } }, '[x](code:x)')
    end
    assert_includes error.message, 'code link x'
  end
end

class CodeLinksCommandTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_undefined_code_link_stops_the_walkthrough_before_github
    Dir.mktmpdir do |dir|
      sentinel = failing_gh(dir)
      content = File.join(dir, 'content.json')
      File.write(content, JSON.generate({ 'summary' => 'See [it](code:missing).', 'code_links' => {} }))
      _output, error, status = Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}" }, COMMAND, 'walkthrough',
                                              'owner/repo', '1', '--head', 'a' * 40, '--content-file', content)
      refute_predicate status, :success?
      assert_includes error, 'undefined code link missing'
      refute_path_exists sentinel
    end
  end

  def failing_gh(dir)
    sentinel = File.join(dir, 'called')
    File.write(File.join(dir, 'gh'), "#!/bin/sh\ntouch #{sentinel}\nexit 1\n")
    File.chmod(0o755, File.join(dir, 'gh'))
    sentinel
  end
end
