# frozen_string_literal: true

require_relative 'evaluation_snapshot_fixture'

module EvaluationWorkflowFixture
  include EvaluationSnapshotFixture

  def setup
    super
    native_git('init', '-q')
  end

  def native_git(*, input: '')
    output, error, status = Open3.capture3(TEST_GIT, '-C', @directory, *, stdin_data: input)
    raise error unless status.success?

    output.strip
  end

  def workflow(text = "jobs:\n  build:\n    steps:\n      - uses: actions/checkout@#{'b' * 40}\n")
    workflow_set('ci.yml' => text)
  end

  def workflow_set(files)
    entries = files.map do |name, text|
      oid = native_git('hash-object', '-w', '--stdin', input: text)
      { 'name' => name, 'mode' => 33_188, 'type' => 'blob', 'oid' => oid,
        'object' => { '__typename' => 'Blob', 'oid' => oid, 'isBinary' => false,
                      'isTruncated' => false, 'byteSize' => text.bytesize, 'text' => text } }
    end
    tree = native_git('mktree', input: entries.map { "100644 blob #{it['oid']}\t#{it['name']}\n" }.join)
    { 'data' => { 'repository' => { 'nameWithOwner' => 'fixture-org/cell',
                                    'object' => { '__typename' => 'Tree', 'oid' => tree, 'entries' => entries } } } }
  end

  def capture_workflows(response = workflow)
    File.write(File.join(@directory, 'responses'), JSON.generate([response]))
    FileUtils.rm_f(File.join(@directory, 'index'))
    Shaka::Evaluation::DeliveryWorkflows.new(repository: 'fixture-org/cell', head: HEAD, github: @gh).read
  end

  def add_directory(response, name)
    tree = response.dig('data', 'repository', 'object')
    tree['entries'] << { 'name' => name, 'mode' => 16_384, 'type' => 'tree',
                         'oid' => native_git('mktree'), 'object' => { '__typename' => 'Tree' } }
    rows = tree.fetch('entries').map { "#{it['mode'].to_s(8)} #{it['type']} #{it['oid']}\t#{it['name']}\n" }
    tree['oid'] = native_git('mktree', input: rows.join)
    response
  end
end
