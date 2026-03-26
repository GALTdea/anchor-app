class ChildProfile < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  belongs_to :space

  enum :status, { active: 0, archived: 1 }, default: :active

  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :date_of_birth, presence: true

  validate :date_of_birth_not_in_future

  scope :active, -> { where(status: :active) }
  scope :archived, -> { where(status: :archived) }

  def name
    "#{first_name} #{last_name}"
  end

  def age
    return nil unless date_of_birth

    now = Time.current.to_date
    age = now.year - date_of_birth.year
    age -= 1 if now.month < date_of_birth.month || (now.month == date_of_birth.month && now.day < date_of_birth.day)
    age
  end

  private

  def date_of_birth_not_in_future
    return if date_of_birth.blank?

    errors.add(:date_of_birth, "cannot be in the future") if date_of_birth > Time.current.to_date
  end
end
