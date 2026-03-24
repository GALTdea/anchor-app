# frozen_string_literal: true

module SettingsHelper
  def multi_tenant_mode?
    AppSettings.multi_tenant_mode
  end

  def show_landing_page?
    AppSettings.show_landing_page
  end
end
