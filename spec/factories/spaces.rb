# == Schema Information
#
# Table name: spaces
#
#  id         :integer          not null, primary key
#  name       :string
#  status     :integer          default("active")
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :space do
    sequence(:name) { |n| "Test Space #{n}" }
    status { :active }

    trait :archived do
      status { :archived }
    end
  end
end
