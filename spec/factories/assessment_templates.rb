# frozen_string_literal: true

# == Schema Information
#
# Table name: assessment_templates
# Database name: primary
#
#  id               :bigint           not null, primary key
#  category         :string
#  respondent_types :jsonb            not null
#  schema           :jsonb            not null
#  slug             :string           not null
#  status           :integer          default("draft"), not null
#  title            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_assessment_templates_on_slug  (slug) UNIQUE
#
FactoryBot.define do
  factory :assessment_template do
    sequence(:title) { |n| "Assessment template #{n}" }
    sequence(:slug) { |n| "template-#{n}" }
    sequence(:template_key) { |n| "assessment-template-#{n}" }
    version { 1 }
    category { "screening" }
    schema do
      {
        "version" => 1,
        "sections" => [
          {
            "id" => "regulation",
            "title" => "Regulation"
          }
        ],
        "questions" => [
          {
            "id" => "concern_level",
            "label" => "Overall level of concern",
            "type" => "scale",
            "section" => "regulation",
            "dimension_key" => "regulation.overall_concern",
            "concept_key" => "overall_concern_level",
            "time_window" => "typical_week",
            "evidence_weight" => 0.8,
            "min" => 1,
            "max" => 5,
            "required" => true
          },
          {
            "id" => "notes",
            "label" => "Notes",
            "type" => "textarea",
            "section" => "regulation",
            "dimension_key" => "regulation.context",
            "concept_key" => "caregiver_context_notes",
            "time_window" => "recent_pattern",
            "evidence_weight" => 0.5,
            "extraction_hint" => "Extract concrete triggers, strengths, and supports mentioned by the caregiver.",
            "required" => false
          }
        ]
      }
    end
    respondent_types { [ "parent_proxy" ] }
    status { :published }

    trait :draft do
      status { :draft }
    end
  end
end
