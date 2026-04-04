# frozen_string_literal: true

class CurrentProfile < ApplicationRecord
  belongs_to :child_profile

  validates :summary, :generated_at, presence: true
  validates :profile_version, numericality: { only_integer: true, greater_than: 0 }
end
