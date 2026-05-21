# frozen_string_literal: true

require "rails_helper"
require "nokogiri"
require Rails.root.join("spec/support/friction_transition_schema")

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
      expect(response.body).to include("Onboarding assessment")
      expect(response.body).to include("0 of 2 answered")
      expect(response.body).to include("Regulation")
      expect(response.body).not_to match(/Question \d+ of \d+/)
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
        current_step_id: "q-concern_level",
        submit_action: "next",
        onboarding_assessment: {
          respondent_kind: "parent_proxy",
          answers: {
            concern_level: "4"
          }
        }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Notes")
      expect(response.body).to include("1 of 2 answered")
      expect(response.body).not_to include("What to expect")
      expect(response.body).not_to include("Onboarding assessment")
      expect(OnboardingSession.last.draft_answers).to include(
        "respondent_kind" => "parent_proxy",
        "answers" => include("concern_level" => "4")
      )
    end

    it "stays on the same step when saving in place" do
      patch onboarding_assessment_path, params: {
        current_step_id: "q-notes",
        submit_action: "stay",
        onboarding_assessment: {
          respondent_kind: "parent_proxy",
          answers: {
            notes: "Autosaved context"
          }
        }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1 of 2 answered")
      expect(OnboardingSession.last.draft_answers).to include(
        "answers" => include("notes" => "Autosaved context")
      )
    end

    it "continues to the account step when required answers are present" do
      patch onboarding_assessment_path, params: {
        submit_action: "continue",
        current_step_id: "q-notes",
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
        current_step_id: "q-notes",
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

    describe "branching with one question per step (Stage 4.8.1)" do
      # Mirrors v3-style branching: follow-up is the next step in the schema
      # (not appended after the whole assessment). Seeds order follow-ups
      # differently; this template isolates "next step = follow-up".
      let!(:branching_onboarding_template) do
        suffix = SecureRandom.hex(3)
        create(
          :assessment_template,
          title: "Branching e2e",
          slug: "branch-one-q-e2e-#{suffix}",
          template_key: "onboarding_branch_one_q_e2e_#{suffix}",
          category: "onboarding",
          schema: {
            "version" => 1,
            "sections" => [ { "id" => "s1", "title" => "Section one" } ],
            "questions" => [
              {
                "id" => "branch_trigger",
                "label" => "Branch trigger question",
                "type" => "select",
                "section" => "s1",
                "dimension_key" => "e2e.branch_trigger",
                "concept_key" => "branch_trigger",
                "time_window" => "current_pattern",
                "evidence_weight" => 0.8,
                "required" => true,
                "options" => [
                  { "label" => "Yes path", "value" => "yes_path" },
                  { "label" => "No path", "value" => "no_path" }
                ]
              },
              {
                "id" => "branch_follow_up",
                "label" => "Follow-up only after yes_path",
                "type" => "select",
                "section" => "s1",
                "dimension_key" => "e2e.branch_follow_up",
                "concept_key" => "branch_follow_up",
                "time_window" => "current_pattern",
                "evidence_weight" => 0.7,
                "required" => false,
                "visible_if" => { "question_id" => "branch_trigger", "equals" => "yes_path" },
                "options" => [
                  { "label" => "Option A", "value" => "a" },
                  { "label" => "Option B", "value" => "b" }
                ]
              },
              {
                "id" => "branch_wrap",
                "label" => "After trigger answered",
                "type" => "textarea",
                "section" => "s1",
                "dimension_key" => "e2e.branch_wrap",
                "concept_key" => "branch_wrap",
                "time_window" => "current_pattern",
                "evidence_weight" => 0.5,
                "required" => false,
                "visible_if" => { "question_id" => "branch_trigger", "answered" => true }
              }
            ]
          }
        )
      end

      around do |example|
        record = AppSettings.first_or_initialize
        record.update!(settings: {}) if record.new_record?
        previous = record.reload.settings["onboarding_assessment_template_id"]
        AppSettings.write_setting!("onboarding_assessment_template_id", branching_onboarding_template.id.to_s)
        example.run
        new_settings = record.reload.settings.dup
        new_settings.delete("onboarding_assessment_template_id")
        new_settings["onboarding_assessment_template_id"] = previous if previous.present?
        record.update!(settings: new_settings)
      end

      it "advances to the follow-up as the very next step with one question on screen" do
        patch onboarding_assessment_path, params: {
          current_step_id: "q-branch_trigger",
          submit_action: "next",
          onboarding_assessment: {
            respondent_kind: "parent_proxy",
            answers: { branch_trigger: "yes_path" }
          }
        }

        expect(response).to have_http_status(:ok)

        doc = Nokogiri::HTML(response.body)
        expect(doc.css("fieldset.fieldset").size).to eq(1)
        expect(doc.at_css("input#current_step_id")["value"]).to eq("q-branch_follow_up")
        expect(response.body).to include("Follow-up only after yes_path")

        session = OnboardingSession.last
        expect(session.draft_answers.dig("answers", "branch_trigger")).to eq("yes_path")
      end
    end

    describe "stop_start_friction → transition_recovery_time (Stage 4.8 Step 9)" do
      let!(:friction_onboarding_template) do
        suffix = SecureRandom.hex(3)
        create(
          :assessment_template,
          title: "Friction onboarding e2e",
          slug: "friction-onboarding-e2e-#{suffix}",
          template_key: "onboarding_friction_e2e_#{suffix}",
          category: "onboarding",
          schema: FRICTION_TRANSITION_E2E_SCHEMA
        )
      end

      around do |example|
        record = AppSettings.first_or_initialize
        record.update!(settings: {}) if record.new_record?
        previous = record.reload.settings["onboarding_assessment_template_id"]
        AppSettings.write_setting!("onboarding_assessment_template_id", friction_onboarding_template.id.to_s)
        example.run
        new_settings = record.reload.settings.dup
        new_settings.delete("onboarding_assessment_template_id")
        new_settings["onboarding_assessment_template_id"] = previous if previous.present?
        record.update!(settings: new_settings)
      end

      it "advances to transition_recovery_time after emotional_collapse" do
        patch onboarding_assessment_path, params: {
          current_step_id: "q-stop_start_friction",
          submit_action: "next",
          onboarding_assessment: {
            respondent_kind: "parent_proxy",
            answers: { stop_start_friction: "emotional_collapse" }
          }
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("how long does it typically take")
      end

      it "skips transition_recovery_time when the answer is stalling" do
        patch onboarding_assessment_path, params: {
          current_step_id: "q-stop_start_friction",
          submit_action: "next",
          onboarding_assessment: {
            respondent_kind: "parent_proxy",
            answers: { stop_start_friction: "stalling" }
          }
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Anything else about transitions")
        expect(response.body).not_to include("how long does it typically take")
      end
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

      onboarding_session = OnboardingSession.last
      expect(response).to redirect_to(space_child_profile_path(onboarding_session.space, onboarding_session.child_profile))
      follow_redirect!
      expect(response.body).to include("Maya&#39;s Support Guide")

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

      onboarding_session = OnboardingSession.last
      expect(response).to redirect_to(space_child_profile_path(onboarding_session.space, onboarding_session.child_profile))
      expect(onboarding_session.user).to eq(existing_user)
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
    it "redirects signed-in users from public onboarding steps back to the child profile" do
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

      onboarding_session = OnboardingSession.last
      expect(response).to redirect_to(space_child_profile_path(onboarding_session.space, onboarding_session.child_profile))
    end
  end
end
