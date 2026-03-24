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
class Subscription < ApplicationRecord
  belongs_to :space
  belongs_to :plan

  scope :active, -> { where(end_date: nil).or(where("end_date > ?", Date.current)) }
end
