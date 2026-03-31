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
require 'rails_helper'

RSpec.describe ChildProfile, type: :model do
  describe 'associations' do
    it 'belongs to space' do
      expect(ChildProfile.reflect_on_association(:space).macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    let(:profile) { build(:child_profile) }

    it 'requires first_name' do
      profile.first_name = nil
      expect(profile).not_to be_valid
      expect(profile.errors[:first_name]).to include("can't be blank")
    end

    it 'requires last_name' do
      profile.last_name = nil
      expect(profile).not_to be_valid
      expect(profile.errors[:last_name]).to include("can't be blank")
    end

    it 'requires date_of_birth' do
      profile.date_of_birth = nil
      expect(profile).not_to be_valid
      expect(profile.errors[:date_of_birth]).to include("can't be blank")
    end

    it 'limits first_name to 100 characters' do
      profile.first_name = "a" * 101
      expect(profile).not_to be_valid
      expect(profile.errors[:first_name]).to include("is too long (maximum is 100 characters)")
    end

    it 'limits last_name to 100 characters' do
      profile.last_name = "a" * 101
      expect(profile).not_to be_valid
      expect(profile.errors[:last_name]).to include("is too long (maximum is 100 characters)")
    end

    it 'rejects future date_of_birth' do
      profile.date_of_birth = 1.day.from_now.to_date
      expect(profile).not_to be_valid
      expect(profile.errors[:date_of_birth]).to include("cannot be in the future")
    end

    it 'accepts past date_of_birth' do
      profile.date_of_birth = 5.years.ago.to_date
      expect(profile).to be_valid
    end
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(ChildProfile.statuses).to include('active' => 0, 'archived' => 1)
    end

    it 'defaults to active status' do
      profile = ChildProfile.new
      expect(profile.status).to eq('active')
    end
  end

  describe 'scopes' do
    let!(:active_profile) { create(:child_profile, status: :active) }
    let!(:archived_profile) { create(:child_profile, status: :archived) }

    it 'returns only active profiles with .active' do
      expect(ChildProfile.active).to contain_exactly(active_profile)
    end

    it 'returns only archived profiles with .archived' do
      expect(ChildProfile.archived).to contain_exactly(archived_profile)
    end
  end

  describe '#name' do
    it 'combines first_name and last_name' do
      profile = build(:child_profile, first_name: "Sam", last_name: "Smith")
      expect(profile.name).to eq("Sam Smith")
    end
  end

  describe '#age' do
    it 'calculates age from date_of_birth' do
      profile = build(:child_profile, date_of_birth: 5.years.ago.to_date)
      expect(profile.age).to eq(5)
    end

    it 'returns nil if date_of_birth is blank' do
      profile = build(:child_profile, date_of_birth: nil)
      expect(profile.age).to be_nil
    end

    it 'accounts for birthday not yet occurring this year' do
      profile = build(:child_profile, date_of_birth: 5.years.ago.to_date + 1.day)
      expect(profile.age).to eq(4)
    end
  end

  describe 'friendly_id' do
    it 'generates a slug from name' do
      profile = create(:child_profile, first_name: "Emma", last_name: "Watson")
      expect(profile.slug).to eq("emma-watson")
    end
  end
end
