# frozen_string_literal: true

class ProfileSnapshot < ApplicationRecord
  belongs_to :child_profile
  belongs_to :trigger_source, polymorphic: true, optional: true
  has_many :recommendations, foreign_key: :source_profile_snapshot_id, dependent: :destroy

  validates :summary, :generated_at, presence: true
end
