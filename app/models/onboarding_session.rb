# frozen_string_literal: true

class OnboardingSession < ApplicationRecord
  belongs_to :assessment_template
  belongs_to :user, optional: true
  belongs_to :space, optional: true
  belongs_to :child_profile, optional: true
  belongs_to :assessment, optional: true
  belongs_to :assessment_response, optional: true

  enum :status, { active: 0, completed: 1, abandoned: 2 }, default: :active

  before_validation :set_started_at, on: :create

  validates :assessment_template, presence: true
  validates :started_at, presence: true
  validates :child_first_name, :child_date_of_birth, presence: true, on: :child_basics

  def child_name
    [ child_first_name, child_last_name ].compact_blank.join(" ")
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end
end
