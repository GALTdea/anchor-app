# frozen_string_literal: true

class AssessmentEvidenceExtractor
  def initialize(assessment_response)
    @assessment_response = assessment_response
  end

  def call
    ProfileEvidence.transaction do
      assessment_response.profile_evidences.delete_all

      build_evidences.each do |attributes|
        assessment_response.profile_evidences.create!(attributes)
      end
    end
  end

  private

  attr_reader :assessment_response

  def build_evidences
    questions.filter_map do |question|
      question = question.stringify_keys
      question_id = question["id"].to_s
      next if question_id.blank?

      answer = answers[question_id]
      next if answer.blank?

      evidence_attributes(question, answer)
    end
  end

  def evidence_attributes(question, answer)
    {
      child_profile: child_profile,
      dimension_key: question["dimension_key"].to_s,
      concept_key: question["concept_key"].to_s,
      value: normalize_value(question, answer),
      value_type: value_type_for(question),
      confidence: question["evidence_weight"].to_f,
      respondent_kind: assessment_response.respondent_kind,
      recorded_at: assessment_response.submitted_at || assessment_response.updated_at || Time.current,
      metadata: metadata_for(question, answer),
      inferred: false
    }
  end

  def normalize_value(question, answer)
    case question["type"].to_s
    when "scale"
      Integer(answer, exception: false).to_s
    else
      answer.to_s
    end
  end

  def value_type_for(question)
    case question["type"].to_s
    when "scale"
      "integer"
    when "select"
      "selection"
    else
      "text"
    end
  end

  def metadata_for(question, answer)
    metadata = {
      "question_id" => question["id"].to_s,
      "question_label" => question["label"].to_s,
      "question_type" => question["type"].to_s,
      "time_window" => question["time_window"].to_s,
      "units" => question["units"].to_s.presence,
      "polarity" => question["polarity"].to_s.presence,
      "evidence_weight" => question["evidence_weight"].to_f,
      "template_slug" => assessment_response.template_slug_snapshot,
      "template_version" => assessment_response.template_version_snapshot
    }.compact

    if question["type"].to_s == "select"
      metadata["selected_option_label"] = selected_option_label(question, answer)
    end

    metadata
  end

  def selected_option_label(question, answer)
    option = Array(question["options"]).find do |candidate|
      if candidate.respond_to?(:stringify_keys)
        candidate.stringify_keys["value"].to_s == answer.to_s
      else
        candidate.to_s == answer.to_s
      end
    end

    return answer.to_s.humanize if option.blank?

    return option.stringify_keys["label"].presence || option.stringify_keys["value"].to_s.humanize if option.respond_to?(:stringify_keys)

    option.to_s.humanize
  end

  def child_profile
    assessment_response.assessment.child_profile
  end

  def questions
    Array(assessment_response.template_schema_snapshot&.dig("questions"))
  end

  def answers
    @answers ||= assessment_response.answers.to_h.stringify_keys
  end
end
