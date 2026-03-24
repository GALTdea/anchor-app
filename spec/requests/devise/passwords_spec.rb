require "rails_helper"

RSpec.describe "Devise Passwords", type: :request do
  let(:user) { create(:user) }

  describe "GET /users/password/new" do
    it "renders the forgot password page" do
      get new_user_password_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /users/password" do
    context "with a valid email" do
      it "does not expose whether the email exists" do
        expect {
          post user_password_path, params: {
            user: { email: user.email }
          }
        }.not_to change(ActionMailer::Base.deliveries, :count)
      end

      it "redirects after sending reset email" do
        post user_password_path, params: {
          user: { email: user.email }
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with an unknown email" do
      it "does not send an email" do
        expect {
          post user_password_path, params: {
            user: { email: "nobody@example.com" }
          }
        }.not_to change(ActionMailer::Base.deliveries, :count)
      end

      it "returns unprocessable entity" do
        post user_password_path, params: {
          user: { email: "nobody@example.com" }
        }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
