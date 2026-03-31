# == Schema Information
#
# Table name: app_settings
# Database name: primary
#
#  id         :bigint           not null, primary key
#  settings   :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_app_settings_on_settings  (settings) USING gin
#
FactoryBot.define do
  factory :app_settings do
    settings { {} }
  end
end
