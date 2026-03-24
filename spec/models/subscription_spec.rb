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
require 'rails_helper'

RSpec.describe Subscription, type: :model do
  describe 'associations' do
    it 'belongs to space' do
      expect(Subscription.reflect_on_association(:space).macro).to eq(:belongs_to)
    end

    it 'belongs to plan' do
      expect(Subscription.reflect_on_association(:plan).macro).to eq(:belongs_to)
    end
  end

  describe 'scopes' do
    describe '.active' do
      let(:space) { create(:space) }
      let(:plan) { create(:plan) }

      context 'when subscription has no end_date' do
        let!(:active_sub) { create(:subscription, space: space, plan: plan, end_date: nil) }

        it 'includes the subscription' do
          expect(Subscription.active).to include(active_sub)
        end
      end

      context 'when subscription has future end_date' do
        let!(:active_sub) { create(:subscription, space: space, plan: plan, end_date: 1.month.from_now) }

        it 'includes the subscription' do
          expect(Subscription.active).to include(active_sub)
        end
      end

      context 'when subscription has past end_date' do
        let!(:expired_sub) { create(:subscription, space: space, plan: plan, end_date: 1.day.ago) }

        it 'excludes the subscription' do
          expect(Subscription.active).not_to include(expired_sub)
        end
      end
    end
  end
end
