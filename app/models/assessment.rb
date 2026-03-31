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
class Assessment < ApplicationRecord
  belongs_to :child_profile
  belongs_to :assessment_template
  belongs_to :assigned_to, class_name: "User", foreign_key: :assigned_to_user_id, optional: true

  has_one :assessment_response, dependent: :destroy

  enum :status, { draft: 0, submitted: 1, archived: 2 }, default: :draft

  validate :template_must_be_published, on: :create

  scope :not_archived, -> { where.not(status: :archived) }

  private

  def template_must_be_published
    return if assessment_template.blank?

    errors.add(:assessment_template, "must be published") unless assessment_template.published?
  end
end
