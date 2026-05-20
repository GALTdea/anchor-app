require 'rails_helper'

RSpec.describe "shared/_flash", type: :view do
  it "renders notices as manually dismissible auto-dismiss success messages" do
    flash[:notice] = "Child profile was successfully created."

    render partial: "shared/flash"

    expect(rendered).to include("Child profile was successfully created.")
    expect(rendered).to include("alert alert-success")
    expect(rendered).to include('role="status"')
    expect(rendered).to include('aria-live="polite"')
    expect(rendered).to include('data-controller="flash"')
    expect(rendered).to include('data-flash-auto-dismiss-value="true"')
    expect(rendered).to include('data-flash-timeout-value="4000"')
    expect(rendered).to include('data-action="flash#dismiss"')
  end

  it "renders alerts as manually dismissible persistent error messages" do
    flash[:alert] = "Something needs attention."

    render partial: "shared/flash"

    expect(rendered).to include("Something needs attention.")
    expect(rendered).to include("alert alert-error")
    expect(rendered).to include('role="alert"')
    expect(rendered).to include('data-controller="flash"')
    expect(rendered).to include('data-action="flash#dismiss"')
    expect(rendered).not_to include('data-flash-auto-dismiss-value="true"')
  end
end
