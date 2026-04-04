# frozen_string_literal: true

class Recommendation < ApplicationRecord
  belongs_to :child_profile
  belongs_to :source_profile_snapshot, class_name: "ProfileSnapshot"

  enum :status, { active: 0, archived: 1 }, default: :active

  validates :category, :title, :body, :generated_at, presence: true
  validates :rationale, presence: true
end
