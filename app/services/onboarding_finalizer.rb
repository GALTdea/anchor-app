# frozen_string_literal: true

class OnboardingFinalizer
  include ActiveModel::Model

  attr_reader :onboarding_session, :account_attributes, :user

  validates :onboarding_session, presence: true

  def initialize(onboarding_session:, account_attributes:)
    @onboarding_session = onboarding_session
    @account_attributes = account_attributes.to_h.symbolize_keys
    @user = nil
    super()
  end

  def call
    return false unless valid?
    return attach_completed_session if onboarding_session.completed?

    ActiveRecord::Base.transaction do
      @user = resolve_user
      raise ActiveRecord::Rollback if errors.any?

      finalize_records!
      run_pipeline_inline!
    end

    errors.empty?
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.full_messages.each { |message| errors.add(:base, message) }
    false
  rescue StandardError => error
    errors.add(:base, error.message)
    false
  end

  private

  def attach_completed_session
    @user = onboarding_session.user
    true
  end

  def resolve_user
    existing_user = User.find_by(email: normalized_email)
    return create_user! if existing_user.blank?

    unless existing_user.valid_password?(account_attributes[:password].to_s)
      errors.add(:base, "Email already exists. Use the correct password to continue with this account.")
      return nil
    end

    existing_user.update!(
      first_name: account_attributes[:first_name].presence || existing_user.first_name,
      last_name: account_attributes[:last_name].presence || existing_user.last_name
    )
    existing_user
  end

  def create_user!
    User.create!(
      email: normalized_email,
      password: account_attributes[:password],
      password_confirmation: account_attributes[:password_confirmation],
      first_name: account_attributes[:first_name],
      last_name: account_attributes[:last_name]
    )
  end

  def finalize_records!
    space = Space.create!(name: OnboardingSpaceNamer.new(onboarding_session).call)
    UserRole.create!(user: user, space: space, role: owner_role)

    child_profile = space.child_profiles.create!(
      first_name: onboarding_session.child_first_name,
      last_name: onboarding_session.child_last_name.presence || "Child",
      date_of_birth: onboarding_session.child_date_of_birth
    )

    assessment = child_profile.assessments.create!(
      assessment_template: onboarding_session.assessment_template,
      status: :submitted
    )

    assessment_response = assessment.create_assessment_response!(
      actor: user,
      respondent_kind: onboarding_session.respondent_kind,
      answers: onboarding_session.assessment_answers,
      submitted_at: Time.current,
      processing_status: "queued",
      last_processed_at: nil,
      last_processing_error: nil
    )

    onboarding_session.update!(
      email: normalized_email,
      parent_name: [ account_attributes[:first_name], account_attributes[:last_name] ].compact_blank.join(" "),
      status: :completed,
      completed_at: Time.current,
      user: user,
      space: space,
      child_profile: child_profile,
      assessment: assessment,
      assessment_response: assessment_response
    )
  end

  def run_pipeline_inline!
    AssessmentEvidenceExtractorJob.perform_now(onboarding_session.assessment_response_id, run_inline: true)
  end

  def owner_role
    Roles::Common.find_or_create_by!(name: "Owner") do |role|
      role.value = "owner"
      role.permissions = Role::AVAILABLE_PERMISSIONS.index_with { "true" }
    end
  end

  def normalized_email
    account_attributes[:email].to_s.strip.downcase
  end
end
