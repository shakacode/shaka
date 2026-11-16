# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'

# Splits test classes among bin/run-tests workers. With class times recorded by an earlier run,
# the longest class goes first to the least-loaded worker, so workers finish close together.
# Without a record, worker N keeps every Nth class by name. Every worker computes the same split
# from the same snapshot, so each class runs in exactly one worker.
module WorkerPlan
  module_function

  def assign(names, workers, seconds)
    names = names.sort
    known = names.filter_map { seconds[it] }
    return Array.new(workers) { |worker| names.select.with_index { |_, i| i % workers == worker } } if known.empty?

    # A class the record lacks, such as a new one, counts as an average class.
    estimate = known.sum / known.size
    balance(names.to_h { [it, seconds.fetch(it, estimate)] }, workers)
  end

  def balance(estimates, workers)
    loads = Array.new(workers, 0.0)
    shares = Array.new(workers) { [] }
    estimates.sort_by { |name, value| [-value, name] }.each do |name, value|
      worker = loads.each_index.min_by { [loads[it], it] }
      loads[worker] += value
      shares[worker] << name
    end
    shares
  end

  # Kept in the repository's shared Git directory, so every worktree of a clone reuses it.
  def record_path(root)
    chosen = ENV.fetch('SHAKA_TEST_DURATIONS', '')
    return chosen unless chosen.empty?

    common, status = Open3.capture2('git', '-C', root, 'rev-parse', '--path-format=absolute', '--git-common-dir',
                                    err: File::NULL)
    File.join(common.strip, 'shaka-test-durations.json') if status.success?
  end

  def read(path)
    times = path && File.exist?(path) ? JSON.parse(File.read(path)) : {}
    times.is_a?(Hash) ? times.select { |name, value| name.is_a?(String) && value.is_a?(Numeric) } : {}
  rescue JSON::ParserError, SystemCallError
    {}
  end

  # A whole-suite run replaces the record; a partial run updates only the classes it ran.
  def write(path, seconds, whole:)
    return unless path

    times = (whole ? {} : read(path)).merge(seconds.reject { |name, _| name.empty? })
    temporary = "#{path}.#{Process.pid}"
    File.write(temporary, JSON.generate(times.sort.to_h))
    File.rename(temporary, path)
  rescue SystemCallError
    FileUtils.rm_f(temporary) if temporary
  end
end
