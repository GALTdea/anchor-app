require "rails_helper"

RSpec.describe "Devise Registrations", type: :request do
  describe "GET /users/sign_up" do
    it "renders the sign up page" do
      get new_user_registration_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /users" do
    context "with valid params" do
      let(:valid_params) do
        {
          user: {
            email: "newuser@example.com",
            password: "password123",
            password_confirmation: "password123",
            first_name: "New",
            last_name: "User"
          }
        }
      end

      it "creates a new user" do
        expect {
          post user_registration_path, params: valid_params
        }.to change(User, :count).by(1)
      end

      it "redirects after successful registration" do
        post user_registration_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          user: {
            email: "",
            password: "short",
            password_confirmation: "short",
            first_name: "New",
            last_name: "User"
          }
        }
      end

      it "does not create a user" do
        expect {
          post user_registration_path, params: invalid_params
        }.not_to change(User, :count)
      end

      it "returns unprocessable entity (Turbo compatible)" do
        post user_registration_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with duplicate email" do
      let!(:existing_user) { create(:user) }

      it "does not create a duplicate user" do
        expect {
          post user_registration_path, params: {
            user: {
              email: existing_user.email,
              password: "password123",
              password_confirmation: "password123",
              first_name: "Dupe",
              last_name: "User"
            }
          }
        }.not_to change(User, :count)
      end
    end
  end
end
