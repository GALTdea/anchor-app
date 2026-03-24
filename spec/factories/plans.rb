# == Schema Information
#
# Table name: plans
#
#  id          :integer          not null, primary key
#  currency    :string           not null
#  description :string
#  duration    :string           not null
#  name        :string           not null
#  price       :float            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  crm_id      :string
#
FactoryBot.define do
  factory :plan do
    name { "Free" }
    price { 0.0 }
    currency { "USD" }
    duration { "monthly" }
    description { {} }

    trait :paid do
      name { "Pro" }
      price { 29.99 }
    end
  end
end
