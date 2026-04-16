# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding flow", type: :request do
  let!(:template) do
    create(
      :assessment_template,
      title: "Parent onboarding",
      template_key: "child-onboarding",
      category: "onboarding"
    )
  end

  describe "GET /" do
    it "shows the child-first CTA on the landing page" do
      get root_path

      expect(response).to be_successful
      expect(response.body).to include("Start your child&#39;s profile")
    end
  end

  describe "POST /onboarding/session" do
    it "creates an onboarding session and redirects to child basics" do
      expect {
        post onboarding_session_path
      }.to change(OnboardingSession, :count).by(1)

      expect(response).to redirect_to(onboarding_child_path)
      follow_redirect!
      expect(response.body).to include("Tell us a little about your child.")
    end

    it "reuses the current browser session instead of creating another record" do
      post onboarding_session_path

      expect {
        post onboarding_session_path
      }.not_to change(OnboardingSession, :count)
    end
  end

  describe "PATCH /onboarding/child" do
    it "saves child basics and redirects to the onboarding assessment step" do
      post onboarding_session_path

      patch onboarding_child_path, params: {
        onboarding_session: {
          child_first_name: "Maya",
          child_last_name: "Rivera",
          child_date_of_birth: "2021-04-14"
        }
      }

      expect(response).to redirect_to(onboarding_assessment_path)
      follow_redirect!
      expect(response.body).to include("Answer a few questions to build a clearer picture.")
      expect(response.body).to include("Continue")
    end

    it "rejects access without an onboarding session in the browser" do
      expect {
        patch onboarding_child_path, params: {
          onboarding_session: {
            child_first_name: "Maya",
            child_date_of_birth: "2021-04-14"
          }
        }
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "PATCH /onboarding/assessment" do
    before do
      post onboarding_session_path
      patch onboarding_child_path, params: {
        onboarding_session: {
          child_first_name: "Maya",
          child_last_name: "Rivera",
          child_date_of_birth: "2021-04-14"
        }
      }
    end

    it "saves a draft and stays on the assessment step" do
      patch onboarding_assessment_path, params: {
        current_step_id: "section-regulation-step-1",
        submit_action: "next",
        onboarding_assessment: {
          respondent_kind: "parent_proxy",
          answers: {
            concern_level: "4"
          }
        }
      }

      expect(response).to redirect_to(onboarding_assessment_path(step: "section-regulation-step-2"))
      follow_redirect!
      expect(response.body).to include("Notes")
      expect(OnboardingSession.last.draft_answers).to include(
        "respondent_kind" => "parent_proxy",
        "answers" => include("concern_level" => "4")
      )
    end

    it "stays on the same step when saving in place" do
      patch onboarding_assessment_path, params: {
        current_step_id: "section-regulation-step-2",
        submit_action: "stay",
        onboarding_assessment: {
          respondent_kind: "parent_proxy",
          answers: {
            notes: "Autosaved context"
          }
        }
      }

      expect(response).to redirect_to(onboarding_assessment_path(step: "section-regulation-step-2"))
      expect(OnboardingSession.last.draft_answers).to include(
        "answers" => include("notes" => "Autosaved context")
      )
    end

    it "continues to the account step when required answers are present" do
      patch onboarding_assessment_path, params: {
        submit_action: "continue",
        current_step_id: "section-regulation-summary",
        onboarding_assessment: {
          respondent_kind: "parent_proxy",
          answers: {
            concern_level: "3",
            notes: "Transitions are hardest after school."
          }
        }
      }

      expect(response).to redirect_to(onboarding_account_path)
      follow_redirect!
      expect(response.body).to include("Save your child's profile.")
      expect(response.body).to include("Your account")
    end

    it "shows validation errors when continuing without required answers" do
      patch onboarding_assessment_path, params: {
        submit_action: "continue",
        current_step_id: "section-regulation-summary",
        onboarding_assessment: {
          respondent_kind: "parent_proxy",
          answers: {
            notes: "Some context"
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Draft answers concern_level is required")
    end
  end

  describe "POST /onboarding/account" do
    before do
      post onboarding_session_path
      patch onboarding_child_path, params: {
        onboarding_session: {
          child_first_name: "Maya",
          child_last_name: "Rivera",
          child_date_of_birth: "2021-04-14"
        }
      }
      patch onboarding_assessment_path, params: {
        submit_action: "continue",
        onboarding_assessment: {
          respondent_kind: "parent_proxy",
          answers: {
            concern_level: "3",
            notes: "Transitions are hardest after school."
          }
        }
      }
    end

    it "creates the durable records and shows results for a new account" do
      expect {
        post onboarding_account_path, params: {
          onboarding_account: {
            first_name: "Ariana",
            last_name: "Rivera",
            email: "ariana@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      }.to change(User, :count).by(1)
        .and change(Space, :count).by(1)
        .and change(ChildProfile, :count).by(1)
        .and change(Assessment, :count).by(1)
        .and change(AssessmentResponse, :count).by(1)
        .and change(CurrentProfile, :count).by(1)
        .and change(Recommendation, :count).by_at_least(1)

      expect(response).to redirect_to(onboarding_results_path)
      follow_redirect!
      expect(response.body).to include("Maya Rivera's first support profile")

      onboarding_session = OnboardingSession.last
      expect(onboarding_session).to be_completed
      expect(onboarding_session.assessment_response.processing_status).to eq("completed")
      expect(controller.current_user.email).to eq("ariana@example.com")
    end

    it "claims an existing account when the password matches" do
      existing_user = create(:user, email: "ariana@example.com", password: "password123", password_confirmation: "password123")

      expect {
        post onboarding_account_path, params: {
          onboarding_account: {
            first_name: "Ariana",
            last_name: "Rivera",
            email: existing_user.email,
            password: "password123",
            password_confirmation: "password123"
          }
        }
      }.not_to change(User, :count)

      expect(response).to redirect_to(onboarding_results_path)
      expect(OnboardingSession.last.user).to eq(existing_user)
    end

    it "rejects an existing email with the wrong password" do
      existing_user = create(:user, email: "ariana@example.com", password: "password123", password_confirmation: "password123")

      expect {
        post onboarding_account_path, params: {
          onboarding_account: {
            first_name: "Ariana",
            last_name: "Rivera",
            email: existing_user.email,
            password: "wrongpassword",
            password_confirmation: "wrongpassword"
          }
        }
      }.not_to change(Space, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Email already exists. Use the correct password to continue with this account.")
    end
  end

  describe "completed onboarding session" do
    it "redirects signed-in users from public onboarding steps back to results" do
      post onboarding_session_path
      patch onboarding_child_path, params: {
        onboarding_session: {
          child_first_name: "Maya",
          child_last_name: "Rivera",
          child_date_of_birth: "2021-04-14"
        }
      }
      patch onboarding_assessment_path, params: {
        submit_action: "continue",
        onboarding_assessment: {
          respondent_kind: "parent_proxy",
          answers: {
            concern_level: "3",
            notes: "Transitions are hardest after school."
          }
        }
      }
      post onboarding_account_path, params: {
        onboarding_account: {
          first_name: "Ariana",
          last_name: "Rivera",
          email: "ariana@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }

      get onboarding_assessment_path

      expect(response).to redirect_to(onboarding_results_path)
    end
  end
end
