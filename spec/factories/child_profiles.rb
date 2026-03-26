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
