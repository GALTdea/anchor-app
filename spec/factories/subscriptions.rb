# == Schema Information
#
# Table name: subscriptions
#
#  id         :integer          not null, primary key
#  end_date   :datetime
#  seats      :integer
#  start_date :datetime         not null
#  plan_id    :integer          not null
#  space_id   :integer          not null
#
# Indexes
#
#  index_subscriptions_on_end_date  (end_date)
#  index_subscriptions_on_plan_id   (plan_id)
#  index_subscriptions_on_space_id  (space_id)
#
FactoryBot.define do
  factory :subscription do
    association :space
    association :plan
    start_date { Date.current }
    seats { 5 }

    trait :active do
      end_date { nil }
    end

    trait :expired do
      end_date { 1.day.ago }
    end
  end
end
