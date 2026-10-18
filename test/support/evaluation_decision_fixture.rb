# frozen_string_literal: true

module EvaluationDecisionFixture
  private

  def decision_run(account = budget, expected: ['handoff'], tier: 1)
    task = tasks.first.merge('tier' => tier)
    trial = Shaka::Evaluation::DecisionTrial.new(runtime: @runtime, usage: @usage,
                                                 tasks: { task.fetch('id') => @task },
                                                 directory: File.join(@directory, 'captures'),
                                                 expected_actions: { task.fetch('id') => expected })
    trial.run([task], budget: account, records: File.join(@directory, 'records')) do |plan, id|
      record(plan, id).merge('score' => 17, 'judge' => [{ 'invented' => true }],
                             'outcome' => { 'state' => 'FAIL', 'harness_error' => nil })
    end
  end

  def export_decision(value)
    path = File.join(@bin, 'harbor')
    script = File.read(path).sub(/^exit\(mode.*\n?\z/, '')
    script << <<~CODE
      FileUtils.mkdir_p(File.join(trial, 'verifier'))
      File.write(File.join(trial, 'verifier/decision.json'), #{JSON.generate(value).inspect})
      exit(mode == 'exit' ? 1 : 0)
    CODE
    File.write(path, script)
  end
end
