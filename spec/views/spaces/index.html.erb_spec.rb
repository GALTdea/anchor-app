require 'rails_helper'

RSpec.describe "spaces/index", type: :view do
  let(:user) { create(:user) }

  before do
    sign_in user
    @spaces = [
      Space.create!(name: "Space 1", status: :active),
      Space.create!(name: "Space 2", status: :active)
    ]
    assign(:spaces, @spaces)
  end

  it "renders a list of spaces" do
    render
    expect(rendered).to include("Space 1")
    expect(rendered).to include("Space 2")
  end
end
