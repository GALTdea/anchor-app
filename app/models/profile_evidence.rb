# frozen_string_literal: true

class ProfileEvidence < ApplicationRecord
  VALUE_TYPES = %w[integer text selection].freeze

  belongs_to :child_profile
  belongs_to :source, polymorphic: true

  validates :dimension_key, :concept_key, :value, :value_type, :respondent_kind, :recorded_at, presence: true
  validates :confidence, numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :value_type, inclusion: { in: VALUE_TYPES }
  validates :metadata, presence: true
  validates :inferred, inclusion: { in: [ true, false ] }

  scope :for_dimension, ->(dimension_key) { where(dimension_key: dimension_key) }
end
