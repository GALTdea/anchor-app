# == Schema Information
#
# Table name: child_profiles
# Database name: primary
#
#  id            :bigint           not null, primary key
#  date_of_birth :date             not null
#  first_name    :string           not null
#  last_name     :string           not null
#  notes         :text
#  slug          :string
#  status        :integer          default("active"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  space_id      :bigint           not null
#
# Indexes
#
#  index_child_profiles_on_slug      (slug) UNIQUE
#  index_child_profiles_on_space_id  (space_id)
#
# Foreign Keys
#
#  fk_rails_...  (space_id => spaces.id)
#
FactoryBot.define do
  factory :child_profile do
    space
    sequence(:first_name) { |n| "Child#{n}" }
    sequence(:last_name) { |n| "Lastname#{n}" }
    date_of_birth { 5.years.ago.to_date }
    status { :active }
    notes { "Sample notes" }

    trait :archived do
      status { :archived }
    end

    trait :infant do
      date_of_birth { 1.year.ago.to_date }
    end

    trait :teen do
      date_of_birth { 14.years.ago.to_date }
    end
  end
end
