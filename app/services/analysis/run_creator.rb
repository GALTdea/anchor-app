# frozen_string_literal: true

module Analysis
  # Creates a completed {AnalysisRun} and {AnalysisFinding} rows, or returns an existing
  # completed run for the same child, rubric, and `input_digest` (idempotent).
  class RunCreator
    ENGINE_VERSION = "1.0.0"

    def initialize(
      child_profile:,
      analysis_rubric:,
      profile_snapshot: nil,
      engine_version: ENGINE_VERSION
    )
      @child_profile = child_profile
      @analysis_rubric = analysis_rubric
      @profile_snapshot = profile_snapshot
      @engine_version = engine_version
    end

    def call
      raise ArgumentError, "analysis rubric must be published" unless analysis_rubric.published?

      child_profile.with_lock do
        input_builder = InputBuilder.new(
          child_profile:,
          profile_snapshot:,
          current_profile: child_profile.current_profile
        )
        payload = input_builder.build
        digest = InputBuilder.digest(payload)

        done = AnalysisRun.find_by(
          child_profile:,
          analysis_rubric:,
          input_digest: digest,
          status: :completed
        )
        return done if done

        run = nil
        ActiveRecord::Base.transaction do
          now = Time.current
          run = AnalysisRun.create!(
            child_profile:,
            analysis_rubric:,
            profile_snapshot:,
            status: :running,
            started_at: now,
            input_digest: digest,
            engine_version:
          )

          findings = RubricEvaluator.new(rubric: analysis_rubric, input: payload).call
          findings.each do |attrs|
            run.analysis_findings.create!(attrs)
          end

          run.update!(status: :completed, completed_at: Time.current)
        end
        run
      end
    end

    private

    attr_reader :child_profile, :analysis_rubric, :profile_snapshot, :engine_version
  end
end
