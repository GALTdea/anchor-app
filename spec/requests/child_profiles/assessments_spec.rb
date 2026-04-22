# frozen_string_literal: true

require "rails_helper"
require "nokogiri"

RSpec.describe "Child profile assessments", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:space) { create(:space) }
  let(:role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }
  let(:child_profile) { create(:child_profile, space: space) }
  let(:template) { create(:assessment_template) }

  before do
    sign_in user
    create(:user_role, user: user, space: space, role: role)
  end

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  describe "GET /index" do
    it "renders successfully" do
      get space_child_profile_assessments_path(space, child_profile)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    it "creates an assessment and response, then redirects to edit response" do
      expect {
        post space_child_profile_assessments_path(space, child_profile),
          params: { assessment: { assessment_template_id: template.id } }
      }.to change(Assessment, :count).by(1)
        .and change(AssessmentResponse, :count).by(1)

      assessment = Assessment.last
      assessment_response = assessment.assessment_response

      expect(response).to redirect_to(
        edit_space_child_profile_assessment_assessment_response_path(space, child_profile, assessment)
      )
      expect(assessment_response.template_slug_snapshot).to eq(template.slug)
      expect(assessment_response.template_version_snapshot).to eq(template.version)
      expect(assessment_response.template_schema_snapshot).to eq(template.schema)
      expect(assessment_response.processing_status).to be_nil
    end
  end

  describe "PATCH /response" do
    let(:assessment) { create(:assessment, child_profile: child_profile, assessment_template: template) }
    let!(:assessment_response) do
      create(:assessment_response, assessment: assessment, actor: user, answers: { "concern_level" => 2 })
    end

    it "merges the current step answers and advances through the runner" do
      patch space_child_profile_assessment_assessment_response_path(space, child_profile, assessment),
        params: {
          current_step_id: "q-concern_level",
          submit_action: "next",
          assessment_response: {
            respondent_kind: "parent_proxy",
            answers: {
              "concern_level" => "3"
            }
          }
        }

      expect(response).to redirect_to(
        edit_space_child_profile_assessment_assessment_response_path(
          space,
          child_profile,
          assessment,
          step: "q-notes"
        )
      )

      assessment_response.reload
      expect(assessment_response.answers).to include("concern_level" => "3")
    end

    it "stays on the same step when saving in place" do
      patch space_child_profile_assessment_assessment_response_path(space, child_profile, assessment),
        params: {
          current_step_id: "q-notes",
          submit_action: "stay",
          assessment_response: {
            respondent_kind: "parent_proxy",
            answers: {
              "notes" => "Autosaved detail"
            }
          }
        }

      expect(response).to redirect_to(
        edit_space_child_profile_assessment_assessment_response_path(
          space,
          child_profile,
          assessment,
          step: "q-notes"
        )
      )

      assessment_response.reload
      expect(assessment_response.answers["notes"]).to eq("Autosaved detail")
    end

    it "submits and marks assessment submitted" do
      assessment_response.update!(last_processing_error: "old failure")

      expect {
        patch space_child_profile_assessment_assessment_response_path(space, child_profile, assessment),
          params: {
            submit_action: "submit",
            assessment_response: {
              respondent_kind: "parent_proxy",
              answers: {
                "concern_level" => "3",
                "notes" => "Done"
              }
            }
          }
      }.to have_enqueued_job(AssessmentEvidenceExtractorJob).with(assessment_response.id)

      expect(response).to redirect_to(space_child_profile_assessment_path(space, child_profile, assessment))
      assessment.reload
      assessment_response.reload
      expect(assessment.status).to eq("submitted")
      expect(assessment_response.submitted_at).to be_present
      expect(assessment_response.processing_status).to eq("queued")
      expect(assessment_response.last_processing_error).to be_nil
      expect(assessment_response.template_slug_snapshot).to eq(template.slug)
      expect(assessment_response.template_version_snapshot).to eq(template.version)
    end

    context "when the template uses hash-shaped select options" do
      let(:hash_select_template) do
        create(:assessment_template, schema: {
          "version" => 1,
          "sections" => [ { "id" => "s1", "title" => "Section" } ],
          "questions" => [
            {
              "id" => "choice",
              "label" => "Pick one",
              "type" => "select",
              "section" => "s1",
              "dimension_key" => "test.dimension",
              "concept_key" => "test_concept",
              "time_window" => "current_pattern",
              "evidence_weight" => 0.8,
              "required" => true,
              "options" => [
                { "label" => "First", "value" => "first" },
                { "label" => "Second", "value" => "second" }
              ]
            }
          ]
        })
      end
      let(:assessment) { create(:assessment, child_profile: child_profile, assessment_template: hash_select_template) }
      let!(:assessment_response) do
        create(:assessment_response, assessment: assessment, actor: user, answers: {})
      end

      it "submits final answers without false invalid-option errors" do
        expect {
          patch space_child_profile_assessment_assessment_response_path(space, child_profile, assessment),
            params: {
              submit_action: "submit",
              current_step_id: "q-choice",
              assessment_response: {
                respondent_kind: "parent_proxy",
                answers: { "choice" => "first" }
              }
            }
        }.to have_enqueued_job(AssessmentEvidenceExtractorJob)

        expect(response).to redirect_to(space_child_profile_assessment_path(space, child_profile, assessment))
        expect(assessment_response.reload.answers["choice"]).to eq("first")
      end
    end

    context "when the template branches to a follow-up on the next step (Stage 4.8.1)" do
      let(:suffix) { SecureRandom.hex(3) }
      let(:branching_schema) do
        {
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
      end
      let(:branching_template) do
        create(
          :assessment_template,
          title: "Branching e2e",
          slug: "child-branch-one-q-e2e-#{suffix}",
          template_key: "child_branch_one_q_e2e_#{suffix}",
          schema: branching_schema
        )
      end
      let(:assessment) { create(:assessment, child_profile: child_profile, assessment_template: branching_template) }
      let!(:assessment_response) { create(:assessment_response, assessment: assessment, actor: user, answers: {}) }

      it "redirects so the next step is only the follow-up question" do
        patch space_child_profile_assessment_assessment_response_path(space, child_profile, assessment),
          params: {
            current_step_id: "q-branch_trigger",
            submit_action: "next",
            assessment_response: {
              respondent_kind: "parent_proxy",
              answers: { "branch_trigger" => "yes_path" }
            }
          }

        expect(response).to redirect_to(
          edit_space_child_profile_assessment_assessment_response_path(
            space,
            child_profile,
            assessment,
            step: "q-branch_follow_up"
          )
        )

        follow_redirect!

        doc = Nokogiri::HTML(response.body)
        expect(doc.css("fieldset.fieldset").size).to eq(1)
        expect(doc.at_css("input#current_step_id")["value"]).to eq("q-branch_follow_up")
        expect(response.body).to include("Follow-up only after yes_path")
      end
    end
  end

  describe "GET /response/edit" do
    let(:assessment) { create(:assessment, child_profile: child_profile, assessment_template: template) }
    let!(:assessment_response) { create(:assessment_response, assessment: assessment, actor: user) }

    it "renders the progressive runner with a single focused step" do
      get edit_space_child_profile_assessment_assessment_response_path(space, child_profile, assessment)

      expect(response).to be_successful
      expect(response.body).to include(template.title)
      expect(response.body).to include(child_profile.name)
      expect(response.body).to include("0 of 2 answered")
      expect(response.body).to include("Continue")
      expect(response.body).not_to include("What to expect")
      expect(response.body).not_to include("prompt")
    end
  end

  describe "authorization" do
    let(:other_user) { create(:user) }
    let(:child_profile) { create(:child_profile, space: space) }

    before do
      sign_in other_user
    end

    it "denies index without role in space" do
      expect {
        get space_child_profile_assessments_path(space, child_profile)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
