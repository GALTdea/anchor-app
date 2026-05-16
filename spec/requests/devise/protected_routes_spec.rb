require "rails_helper"

RSpec.describe "Protected Routes", type: :request do
  let(:user) { create(:user) }

  describe "accessing authenticated routes" do
    context "when not signed in" do
      it "redirects to sign in page" do
        get spaces_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      it "allows access to spaces index in multi-tenant mode" do
        sign_in user
        get spaces_path
        expect(response).to have_http_status(:ok)
      end

      it "allows access to home" do
        sign_in user
        get home_path
        expect(response).to have_http_status(:ok)
      end

      it "redirects single-family parents from spaces index to home" do
        allow(AppSettings).to receive(:multi_tenant_mode).and_return(false)
        sign_in user
        get spaces_path
        expect(response).to redirect_to(home_path)
      end
    end
  end

  describe "accessing public routes" do
    context "when not signed in" do
      it "allows access to sign in page" do
        get new_user_session_path
        expect(response).to have_http_status(:ok)
      end

      it "allows access to sign up page" do
        get new_user_registration_path
        expect(response).to have_http_status(:ok)
      end

      it "allows access to forgot password page" do
        get new_user_password_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
