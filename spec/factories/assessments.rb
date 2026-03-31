# frozen_string_literal: true

# == Schema Information
#
# Table name: assessments
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  status                 :integer          default("draft"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  assessment_template_id :bigint           not null
#  assigned_to_user_id    :integer
#  child_profile_id       :bigint           not null
#
# Indexes
#
#  index_assessments_on_assessment_template_id  (assessment_template_id)
#  index_assessments_on_child_profile_id        (child_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (assessment_template_id => assessment_templates.id)
#  fk_rails_...  (assigned_to_user_id => users.id)
#  fk_rails_...  (child_profile_id => child_profiles.id)
#
FactoryBot.define do
  factory :assessment do
    child_profile
    assessment_template
    status { :draft }
    assigned_to_user_id { nil }
  end
end
