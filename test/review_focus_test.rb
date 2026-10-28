# frozen_string_literal: true

require_relative 'walkthrough_code_links_test'
require 'shaka/review_focus'

# A focus entry links the lines it names at the head the description describes, and is refused
# when the PR does not change that file there, so a reviewer is never sent to missing code.
class ReviewFocusTest < Minitest::Test
  include CodeLinksFixtures

  FILES = [{ 'filename' => 'lib/package.rb', 'status' => 'modified' },
           { 'filename' => 'bin/tool.py', 'status' => 'renamed', 'previous_filename' => 'bin/old.py' },
           { 'filename' => 'lib/gone.rb', 'status' => 'removed' }].freeze

  def resolve(*entries, client: github)
    content = { 'intent' => { 'review_focus' => entries } }
    pull = { 'head' => { 'sha' => HEAD }, 'shaka_changed_files' => FILES }
    Shaka::ReviewFocus.resolve(content, client, pull)
  end

  def entry(path, **anchor) = { 'path' => path, 'level' => 4, 'reason' => 'r.' }.merge(anchor.transform_keys(&:to_s))

  def test_a_range_links_the_lines_its_text_finds_at_the_head
    focus = resolve(entry('lib/package.rb', from: 'def stage', block: true))

    assert_equal [{ 'url' => "#{BLOB}/lib/package.rb#L6-L9", 'lines' => [6, 9] }], focus
  end

  def test_a_whole_file_entry_links_the_file_without_reading_it
    client = github

    assert_equal [{ 'url' => "#{BLOB}/bin/tool.py", 'lines' => nil }], resolve(entry('bin/tool.py'), client:)
    assert_empty client.requests
  end

  # The renderer reads a null from as a whole-file entry, so the resolver must too.
  def test_a_null_start_links_the_whole_file
    assert_equal [{ 'url' => "#{BLOB}/bin/tool.py", 'lines' => nil }], resolve(entry('bin/tool.py', from: nil))
  end

  def test_files_the_pr_leaves_absent_at_the_head_are_refused
    ['lib/gone.rb', 'bin/old.py', 'lib/untouched.rb'].each do |path|
      error = assert_raises(Shaka::Error) { resolve(entry(path)) }
      assert_includes error.message, 'Publication intent review_focus 1'
      assert_includes error.message, 'not present at the head'
    end
  end

  def test_missing_or_ambiguous_start_text_is_refused_as_an_intent_error
    [entry('lib/package.rb', from: 'def missing'), entry('lib/package.rb', from: '(root)')].each do |focus|
      error = assert_raises(Shaka::Error) { resolve(entry('bin/tool.py'), focus) }
      assert_match(/\APublication intent review_focus 2: /, error.message)
    end
  end

  def test_content_without_a_well_formed_list_is_left_to_the_renderer
    pull = { 'head' => { 'sha' => HEAD }, 'shaka_changed_files' => FILES }

    assert_nil Shaka::ReviewFocus.resolve({ 'intent' => {} }, github, pull)
    assert_nil Shaka::ReviewFocus.resolve({ 'intent' => { 'review_focus' => ['x'] } }, github, pull)
  end
end
