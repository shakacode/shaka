# frozen_string_literal: true

require_relative 'publication_test'

# Counts stay complete even when the expandable path list must be shortened.
class PublicationDiffBucketsTest < Minitest::Test
  def test_buckets_count_each_current_filename_once_and_expose_the_paths
    paths = %w[lib/main.rb test/main_test.rb spec/main_spec.rb src/main.test.ts docs/guide.md
               skills/shaka/config/workflow.yml assets/logo.svg config.yml]
    pull = { 'changed_files' => paths.size, 'additions' => 12, 'deletions' => 3,
             'shaka_changed_files' => paths.map { |path| { 'filename' => path } } }
    pull['shaka_changed_files'].first['previous_filename'] = 'test/old.rb'
    rendered = Shaka::DiffBuckets.render(pull).join
    assert_includes rendered, '<summary>Files: Code 1 · Tests 3 · Docs/instructions 2 · Other 2'
    paths.each { |path| assert_includes rendered, "- `#{path}`" }
    refute_includes rendered, '- `test/old.rb`'
  end

  def test_incomplete_file_lists_do_not_publish_bucket_counts
    pull = { 'changed_files' => 2, 'additions' => 12, 'deletions' => 3,
             'shaka_changed_files' => [{ 'filename' => 'test/main_test.rb' }] }
    refute_includes Shaka::DiffBuckets.render(pull).join, '<summary>Files:'
  end

  def test_large_path_lists_are_bounded_without_losing_bucket_counts
    files = Array.new(300) { |index| { 'filename' => "lib/#{index}#{'a' * 220}.rb" } }
    pull = { 'changed_files' => files.size, 'shaka_changed_files' => files,
             'html_url' => 'https://github.com/owner/repo/pull/1' }
    rendered = Shaka::DiffBuckets.render(pull).join
    assert_includes rendered, '<summary>Files: Code 300'
    assert_includes rendered, '300 paths omitted'
    assert_includes rendered, '[All changed files](https://github.com/owner/repo/pull/1/files)'
    assert_operator publication_for(pull).length, :<, 65_536
  end

  def test_many_short_paths_are_limited_to_forty_displayed_paths
    files = Array.new(100) { |index| { 'filename' => "test/example_#{index}.rb" } }
    rendered = Shaka::DiffBuckets.render('changed_files' => 100, 'shaka_changed_files' => files).join
    assert_includes rendered, '<summary>Files: Tests 100'
    assert_equal 40, rendered.scan(/^- `/).size
    assert_includes rendered, '60 paths omitted'
  end

  private

  def publication_for(pull)
    pull = pull.merge('head' => { 'sha' => 'a' * 40 })
    Shaka::Publication.description(PublicationRegressionTest.new(name).description_content, nil, pull)
  end
end
