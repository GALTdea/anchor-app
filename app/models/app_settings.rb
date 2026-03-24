# frozen_string_literal: true

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
class AppSettings < ApplicationRecord
  require "type_cast"

  after_save :clear_memoization

  Rails.application.config.app_settings.each do |key, schema|
    define_singleton_method(key) do
      raw_value = global_settings[key] || schema["default"]

      TypeCast::FUNCTION_MAPPER[schema["type"]].call(raw_value)
    end
  end

  class << self
    def clear_memoization
      @global_settings = nil
    end

    private

    def global_settings
      @global_settings ||= (first&.settings || {})
    end
  end

  private

  def clear_memoization
    self.class.clear_memoization
  end
end
