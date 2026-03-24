require "rails_helper"

RSpec.describe "Devise Sessions", type: :request do
  let(:user) { create(:user, password: "password123") }

  describe "GET /users/sign_in" do
    context "when not signed in" do
      it "renders the sign in page" do
        get new_user_session_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when already signed in" do
      it "redirects away from sign in page" do
        sign_in user
        get new_user_session_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /users/sign_in" do
    context "with valid credentials" do
      it "signs in successfully and redirects" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "password123"
          }
        }
        expect(response).to redirect_to(root_path)
      end
    end

    context "with invalid password" do
      it "returns unprocessable entity (Turbo compatible)" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "wrongpassword"
          }
        }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with unknown email" do
      it "returns unprocessable entity" do
        post user_session_path, params: {
          user: {
            email: "nobody@example.com",
            password: "password123"
          }
        }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /users/sign_out" do
    context "when signed in" do
      it "signs out and redirects to root" do
        sign_in user
        delete destroy_user_session_path
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
