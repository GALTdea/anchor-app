# frozen_string_literal: true

module AssessmentRespondentKinds
  extend ActiveSupport::Concern

  CANONICAL = %w[parent_proxy self_report therapist_report teacher_report].freeze
end
