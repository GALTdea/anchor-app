class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include SettingsHelper
  include Pagy::Backend
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!, except: [ :landing ]
  before_action :redirect_signed_in_user, only: [ :landing ]

  layout :determine_layout

  def landing; end

  private

  def determine_layout
    if devise_controller?
      "devise"
    elsif user_signed_in?
      "dashboard"
    else
      "application"
    end
  end

  def redirect_signed_in_user
    return unless user_signed_in?

    redirect_to home_path
  end
end
