# frozen_string_literal: true

module EvaluationSnapshotFixture
  HEAD = 'a' * 40

  def setup
    @directory = Dir.mktmpdir('delivery-snapshot')
    @gh = File.join(@directory, 'gh')
    source = File.read(File.expand_path('../fixtures/evaluation_delivery/snapshot_gh.txt', __dir__))
    File.write(@gh, "#!#{RbConfig.ruby}\n#{source}")
    File.chmod(0o755, @gh)
  end

  def teardown = FileUtils.remove_entry(@directory)

  def pull
    { 'data' => { 'repository' => { 'nameWithOwner' => 'fixture-org/cell', 'pullRequest' => {
      'number' => 1, 'state' => 'OPEN', 'headRefOid' => HEAD, 'baseRefOid' => 'b' * 40,
      'merged' => false, 'mergeCommit' => nil, 'headRepository' => { 'nameWithOwner' => 'fixture-org/cell' },
      'changedFiles' => 1, 'files' => { 'totalCount' => 1, 'pageInfo' => { 'hasNextPage' => false },
                                        'nodes' => [{ 'path' => 'lib/a space.rb', 'changeType' => 'MODIFIED' }] }
    } } } }
  end

  def checks
    { 'total_count' => 1, 'check_runs' => [
      { 'id' => 118_040_128_127, 'name' => 'validate', 'head_sha' => HEAD,
        'status' => 'completed', 'conclusion' => 'success', 'app' => { 'id' => 15_368 },
        'check_suite' => { 'id' => 7 } }
    ] }
  end

  def blobs
    { 'data' => { 'repository' => { 'b0' => {
      '__typename' => 'Blob', 'oid' => 'c' * 40, 'isBinary' => false, 'isTruncated' => false,
      'byteSize' => 5, 'text' => "a\nb\nc"
    } } } }
  end

  def capture(rows = [pull, checks, blobs, pull], **)
    File.write(File.join(@directory, 'responses'), JSON.generate(rows))
    FileUtils.rm_f(File.join(@directory, 'index'))
    Shaka::Evaluation::DeliverySnapshot.new(plan, github: @gh, **).read
  end

  def plan
    { 'repository' => 'fixture-org/cell', 'number' => 1, 'head' => HEAD, 'check_apps' => { 'validate' => 15_368 } }
  end

  def requests = File.readlines(File.join(@directory, 'requests')).map { JSON.parse(it) }
end
