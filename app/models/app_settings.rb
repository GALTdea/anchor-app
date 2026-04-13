# frozen_string_literal: true

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

    def write_setting!(key, value)
      record = first_or_initialize
      updated_settings = record.settings.merge(key.to_s => value)
      record.update!(settings: updated_settings)
      record
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
