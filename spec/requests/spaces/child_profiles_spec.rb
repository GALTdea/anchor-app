require 'rails_helper'

RSpec.describe "/spaces/:space_id/child_profiles", type: :request do
  let(:user) { create(:user) }
  let(:space) { create(:space) }
  let(:role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }

  before do
    sign_in user
    create(:user_role, user: user, space: space, role: role)
  end

  describe "GET /index" do
    it "renders a successful response" do
      create(:child_profile, space: space)
      get space_child_profiles_url(space)
      expect(response).to be_successful
    end

    it "shows only active child profiles" do
      active = create(:child_profile, space: space, status: :active)
      archived = create(:child_profile, space: space, status: :archived)
      get space_child_profiles_url(space)
      expect(response.body).to include(active.name)
      expect(response.body).not_to include(archived.name)
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      child_profile = create(:child_profile, space: space)
      get space_child_profile_url(space, child_profile)
      expect(response).to be_successful
    end

    it "renders the child profile as the Support Guide without raw narrative or internal analysis copy" do
      child_profile = create(:child_profile, space: space, first_name: "Maya", last_name: "Rivera")
      create(:current_profile, child_profile: child_profile, narrative: "Maya has a profile narrative.", summary: {
        "dimensions" => {
          "strengths.interests" => {
            "latest_value" => "Dinosaurs",
            "confidence" => 0.8,
            "respondent_kind" => "parent_proxy",
            "recorded_at" => Time.current.iso8601
          },
          "communication.expressive" => {
            "latest_value" => "Uses short phrases",
            "confidence" => 0.8,
            "respondent_kind" => "parent_proxy",
            "recorded_at" => Time.current.iso8601,
            "evidence_count" => 1
          }
        }
      })
      snapshot = create(:profile_snapshot, child_profile: child_profile)
      create(
        :recommendation,
        child_profile: child_profile,
        source_profile_snapshot: snapshot,
        title: "Use visual supports",
        body: "Try one visual support during transitions.",
        rationale: { "display_value" => "Uses short phrases" }
      )
      template = create(:assessment_template, title: "Anchor Onboarding Profile")
      assessment = create(:assessment, child_profile: child_profile, assessment_template: template, status: :submitted)
      create(:assessment_response, assessment: assessment, submitted_at: Time.current, processing_status: "completed")

      analysis_rubric = create(
        :analysis_rubric, :published,
        rubric_key: "page_show_test",
        version: 1,
        schema: { "version" => 1, "domains" => [] }
      )
      analysis_run = create(:analysis_run, :completed, child_profile: child_profile, analysis_rubric: analysis_rubric)
      create(
        :analysis_finding,
        analysis_run: analysis_run,
        dimension_key: "communication",
        finding_key: "communication.support_signal",
        label: "Communication support signal",
        summary: "This is a deterministic support signal shown on the profile home.",
        confidence: 0.72,
        evidence_refs: { "profile_evidence_ids" => [ 1 ] }
      )
      ai_unique = "UNIQUEAISUMMARYSNIPPET_RESULTS_HOME_VISIBILITY"
      create(
        :ai_synthesis_run, :completed,
        analysis_run: analysis_run,
        purpose: ChildProfileResultsPresenter::AI_SYNTHESIS_PURPOSE_PARENT,
        output: {
          "summary_plain" =>
            "#{ai_unique} Extra words so deterministic analysis remains the grounding source for Anchor's profile views here.",
          "synthesis_schema_version" => "anchor_synthesis_v1",
          "confidence_note" => "Stub certainty still tracks low sample size for some signals.",
          "what_to_watch" => [ "How communication shifts between calm and hurried moments." ],
          "finding_refs" => []
        }
      )

      get space_child_profile_url(space, child_profile)

      expect(response).to be_successful
      expect(response.body).not_to include(ai_unique)
      expect(response.body).not_to include("Stub certainty")
      expect(response.body).not_to include("Maya has a profile narrative.")
      expect(response.body).to include("Maya&#39;s Support Guide")
      expect(response.body).to include("Child Snapshot")
      expect(response.body).to include("What Anchor Understands Right Now")
      expect(response.body.scan("data-support-domain-card=").length).to eq(5)
      expect(response.body.scan("data-support-domain-card=\"communication_expression\"").length).to eq(1)
      expect(response.body).to include("Communication &amp; Expression")
      expect(response.body).to include("Social Connection Style")
      expect(response.body).to include("Support direction")
      expect(response.body).to include("support_domains/communication_expression")
      expect(response.body).to include("support_domains/social_connection_style")
      expect(response.body).to include("When Things Get Hard")
      expect(response.body).to include("What to Plan Around")
      expect(response.body).to include("Best Support Style")
      expect(response.body).to include("Focus Right Now")
      expect(response.body).to include("Try This This Week")
      expect(response.body).to include("What We're Still Learning")
      expect(response.body).to include("A simple guide to what Anchor understands right now")
      expect(response.body).to include("Dinosaurs")
      expect(response.body).to include("Uses short phrases")
      expect(response.body).to include("Try one visual support during transitions.")
      expect(response.body).to include("Use visual supports")
      expect(response.body).to include("Why it may help")
      expect(response.body).to include("How to try it")
      expect(response.body).to include("Anchor Onboarding Profile")
      expect(response.body).to include("Based on Anchor Onboarding Profile")
      expect(response.body).to include("Recommendations")
      expect(response.body).to include("Assessments")
      expect(response.body).to include("Edit child details")
      expect(response.body).to include("Full profile details")
      expect(response.body).to include("View all recommendations")
      expect(response.body).to include("may")
      expect(response.body).not_to include("Communication support signal")
      expect(response.body).not_to include("deterministic support signal")
      expect(response.body).not_to include("What May Be Driving This")
      expect(response.body).not_to include("Profile signals")
      expect(response.body).not_to include("confidence score")
      expect(response.body).not_to include("evidence count")
      expect(response.body).not_to include("dimension key")
      expect(response.body).not_to include("profile version")
      expect(response.body).not_to include("Recommended next steps")
      expect(response.body).not_to include("Based on:")
      expect(response.body).not_to include("Plain-language Summary")
    end

    it "shows empty Support Guide placeholders when there is no current profile yet" do
      child_profile = create(:child_profile, space: space, first_name: "Noah", last_name: "Lee")

      get space_child_profile_url(space, child_profile)

      expect(response).to be_successful
      expect(response.body).to include("Noah&#39;s Support Guide")
      expect(response.body).to include("Child Snapshot")
      expect(response.body).to include("What Anchor Understands Right Now")
      expect(response.body).to include("When Things Get Hard")
      expect(response.body).to include("Noah may do best when expectations are clear before a task starts.")
      expect(response.body).to include("Make uncertain moments more predictable")
      expect(response.body).to include("Preview one tricky transition")
      expect(response.body).to include("Start onboarding assessment")
      expect(response.body).to include(start_onboarding_space_child_profile_assessments_path(space, child_profile))
      expect(response.body).not_to include("Profile signals")
    end

    it "does not show the onboarding assessment CTA after a submitted assessment exists" do
      child_profile = create(:child_profile, space: space, first_name: "Lena", last_name: "Park")
      template = create(:assessment_template, title: "Submitted template")
      assessment = create(:assessment, child_profile: child_profile, assessment_template: template, status: :submitted)
      create(:assessment_response, assessment: assessment, actor: user, submitted_at: Time.current, processing_status: "completed")

      get space_child_profile_url(space, child_profile)

      expect(response).to be_successful
      expect(response.body).not_to include("Start onboarding assessment")
    end

    it "does not dump CurrentProfile narrative on the Support Guide when recommendations fall back" do
      child_profile = create(:child_profile, space: space, first_name: "Riley", last_name: "Kim")
      create(:current_profile, child_profile: child_profile, narrative: "Riley narrative from the latest profile pass.", summary: {
        "dimensions" => {
          "communication.expressive" => {
            "latest_value" => "Mostly single words",
            "confidence" => 0.7,
            "respondent_kind" => "parent_proxy",
            "recorded_at" => Time.current.iso8601,
            "evidence_count" => 1
          }
        }
      })
      template = create(:assessment_template, title: "Check-in survey")
      assessment = create(:assessment, child_profile: child_profile, assessment_template: template, status: :submitted)
      create(:assessment_response, assessment: assessment, actor: user, submitted_at: Time.current, processing_status: "completed")

      get space_child_profile_url(space, child_profile)

      expect(response).to be_successful
      expect(response.body).to include("Riley&#39;s Support Guide")
      expect(response.body).not_to include("Riley narrative from the latest profile pass.")
      expect(response.body).to include("Mostly single words")
      expect(response.body).to include("Preview one tricky transition")
      expect(response.body).not_to include("Based on:")
    end

    it "shows no more than three support priorities and three weekly ideas" do
      child_profile = create(:child_profile, space: space, first_name: "Ari", last_name: "Stone")
      create(:current_profile, child_profile: child_profile, narrative: "Ari profile narrative.", summary: {
        "dimensions" => {
          "communication.expressive" => dimension_details("Uses short phrases"),
          "sensory.sensitivity" => dimension_details("Sensitive to loud sounds"),
          "regulation.recovery" => dimension_details("Needs quiet recovery"),
          "adaptive.routines" => dimension_details("Uses familiar routines")
        }
      })
      snapshot = create(:profile_snapshot, child_profile: child_profile)

      4.times do |index|
        create(
          :recommendation,
          child_profile: child_profile,
          source_profile_snapshot: snapshot,
          category: "communication",
          title: "Weekly idea #{index}",
          body: "Try support #{index} this week."
        )
      end

      get space_child_profile_url(space, child_profile)

      expect(response).to be_successful
      expect(response.body.scan("Make communication easier to use").length).to eq(3)
      expect(response.body.scan("Weekly idea").length).to eq(3)
    end

    it "surfaces queued assessment processing on the results home" do
      child_profile = create(:child_profile, space: space, first_name: "Quinn", last_name: "Patel")
      template = create(:assessment_template, title: "Queued template")
      assessment = create(:assessment, child_profile: child_profile, assessment_template: template, status: :submitted)
      create(
        :assessment_response,
        assessment: assessment,
        actor: user,
        submitted_at: Time.current,
        processing_status: "queued"
      )

      get space_child_profile_url(space, child_profile)

      expect(response).to be_successful
      expect(response.body).to include("Profile update queued")
      expect(response.body).to include("We saved what has been shared so far and are building this profile.")
      expect(response.body).to include("Gentle starting points")
    end

    it "surfaces failed assessment processing on the results home" do
      child_profile = create(:child_profile, space: space, first_name: "Sky", last_name: "Nguyen")
      template = create(:assessment_template, title: "Failed run template")
      assessment = create(:assessment, child_profile: child_profile, assessment_template: template, status: :submitted)
      create(
        :assessment_response,
        assessment: assessment,
        actor: user,
        submitted_at: Time.current,
        processing_status: "failed"
      )

      get space_child_profile_url(space, child_profile)

      expect(response).to be_successful
      expect(response.body).to include("Profile update needs retry")
      expect(response.body).to include("We saved the assessment, but the profile update needs attention before these results can be refreshed.")
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_space_child_profile_url(space)
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      child_profile = create(:child_profile, space: space)
      get edit_space_child_profile_url(space, child_profile)
      expect(response).to be_successful
    end
  end

  describe "POST /assessments/start_onboarding" do
    let!(:onboarding_template) do
      create(
        :assessment_template,
        title: "Child onboarding",
        template_key: "child-onboarding",
        category: "onboarding"
      )
    end
    let(:child_profile) { create(:child_profile, space: space) }

    it "starts the configured onboarding assessment directly" do
      expect {
        post start_onboarding_space_child_profile_assessments_url(space, child_profile)
      }.to change(Assessment, :count).by(1)
        .and change(AssessmentResponse, :count).by(1)

      assessment = child_profile.assessments.last
      expect(assessment.assessment_template).to eq(onboarding_template)
      expect(assessment.assessment_response).to be_draft
      expect(response).to redirect_to(
        edit_space_child_profile_assessment_assessment_response_url(space, child_profile, assessment)
      )
    end

    it "resumes an existing draft onboarding assessment" do
      assessment = create(:assessment, child_profile: child_profile, assessment_template: onboarding_template)
      create(:assessment_response, assessment: assessment, actor: user, answers: {})

      expect {
        post start_onboarding_space_child_profile_assessments_url(space, child_profile)
      }.not_to change(Assessment, :count)

      expect(response).to redirect_to(
        edit_space_child_profile_assessment_assessment_response_url(space, child_profile, assessment)
      )
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      let(:valid_attributes) do
        {
          first_name: "Emma",
          last_name: "Watson",
          date_of_birth: 5.years.ago.to_date,
          notes: "Sample notes"
        }
      end

      it "creates a new ChildProfile" do
        expect {
          post space_child_profiles_url(space), params: { child_profile: valid_attributes }
        }.to change(ChildProfile, :count).by(1)
      end

      it "redirects to the created child_profile" do
        post space_child_profiles_url(space), params: { child_profile: valid_attributes }
        expect(response).to redirect_to(space_child_profile_url(space, ChildProfile.last))
      end

      it "creates a child profile without a last name" do
        expect {
          post space_child_profiles_url(space), params: {
            child_profile: valid_attributes.merge(last_name: "")
          }
        }.to change(ChildProfile, :count).by(1)

        expect(ChildProfile.last.last_name).to eq("")
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        {
          first_name: "",
          last_name: "",
          date_of_birth: nil
        }
      end

      it "does not create a new ChildProfile" do
        expect {
          post space_child_profiles_url(space), params: { child_profile: invalid_attributes }
        }.not_to change(ChildProfile, :count)
      end

      it "renders the new template with unprocessable_content status" do
        post space_child_profiles_url(space), params: { child_profile: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    let(:child_profile) { create(:child_profile, space: space) }

    context "with valid parameters" do
      let(:new_attributes) do
        {
          first_name: "Updated",
          last_name: "Name"
        }
      end

      it "updates the child_profile" do
        patch space_child_profile_url(space, child_profile), params: { child_profile: new_attributes }
        child_profile.reload
        expect(child_profile.first_name).to eq("Updated")
        expect(child_profile.last_name).to eq("Name")
      end

      it "redirects to the child_profile" do
        patch space_child_profile_url(space, child_profile), params: { child_profile: new_attributes }
        expect(response).to redirect_to(space_child_profile_url(space, child_profile))
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        {
          first_name: "",
          last_name: ""
        }
      end

      it "renders the edit template with unprocessable_content status" do
        patch space_child_profile_url(space, child_profile), params: { child_profile: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    let!(:child_profile) { create(:child_profile, space: space) }

    it "archives the child_profile" do
      delete space_child_profile_url(space, child_profile)
      child_profile.reload
      expect(child_profile.status).to eq("archived")
    end

    it "redirects to the child_profiles list" do
      delete space_child_profile_url(space, child_profile)
      expect(response).to redirect_to(space_child_profiles_url(space))
    end
  end

  describe "authorization" do
    let(:unauthorized_user) { create(:user) }
    let(:child_profile) { create(:child_profile, space: space) }

    before do
      sign_in unauthorized_user
    end

    it "denies access to index without role in space" do
      expect {
        get space_child_profiles_url(space)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "denies access to show (results home) without role in space" do
      expect {
        get space_child_profile_url(space, child_profile)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "denies access to new without role in space" do
      expect {
        get new_space_child_profile_url(space)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  def dimension_details(value)
    {
      "latest_value" => value,
      "confidence" => 0.8,
      "respondent_kind" => "parent_proxy",
      "recorded_at" => Time.current.iso8601,
      "evidence_count" => 1
    }
  end
end
