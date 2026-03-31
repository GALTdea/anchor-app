# frozen_string_literal: true

# == Schema Information
#
# Table name: assessment_responses
# Database name: primary
#
#  id              :bigint           not null, primary key
#  answers         :jsonb            not null
#  respondent_kind :string           not null
#  submitted_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  actor_id        :integer          not null
#  assessment_id   :bigint           not null
#
# Indexes
#
#  index_assessment_responses_on_assessment_id  (assessment_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (assessment_id => assessments.id)
#
FactoryBot.define do
  factory :assessment_response do
    assessment
    association :actor, factory: :user
    respondent_kind { "parent_proxy" }
    answers { {} }
    submitted_at { nil }
  end
end
