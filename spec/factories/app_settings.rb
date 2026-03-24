# == Schema Information
#
# Table name: app_settings
#
#  id         :integer          not null, primary key
#  settings   :json             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_app_settings_on_settings  (settings)
#
FactoryBot.define do
  factory :app_settings do
    settings { {} }
  end
end
