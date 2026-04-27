# frozen_string_literal: true

module Analysis
  # Builds a stable, hash-based payload for `Analysis::RubricEvaluator` and
  # {Analysis::RunCreator}. Used to compute a deterministic `input_digest`.
  class InputBuilder
    VERSION = 1

    def initialize(child_profile:, profile_snapshot: nil, current_profile: nil)
      @child_profile = child_profile
      @profile_snapshot = profile_snapshot
      @current_profile = current_profile
    end

    def build
      {
        "builder_version" => VERSION,
        "child_profile" => child_profile_hash,
        "evidence" => evidence_payload,
        "current_profile" => current_profile_hash,
        "profile_snapshot" => profile_snapshot_hash
      }
    end

    def self.digest(payload)
      canonical = sort_keys_for_json(payload)
      body = JSON.generate(canonical)
      Digest::SHA256.hexdigest(body)
    end

    def digest
      self.class.digest(build)
    end

    def self.sort_keys_for_json(obj)
      case obj
      when Hash
        obj.keys.sort.index_with { |k| sort_keys_for_json(obj[k]) }
      when Array
        obj.map { |v| sort_keys_for_json(v) }
      else
        obj
      end
    end

    private

    attr_reader :child_profile, :profile_snapshot

    def current_profile
      @current_profile ||= child_profile.current_profile
    end

    def child_profile_hash
      {
        "id" => child_profile.id,
        "first_name" => child_profile.first_name,
        "last_name" => child_profile.last_name,
        "date_of_birth" => child_profile.date_of_birth&.iso8601
      }
    end

    def evidence_payload
      child_profile
        .profile_evidences
        .unscope(:order)
        .order(:id)
        .map { |e| serialize_evidence(e) }
    end

    def serialize_evidence(evidence)
      {
        "id" => evidence.id,
        "dimension_key" => evidence.dimension_key,
        "concept_key" => evidence.concept_key,
        "value" => evidence.value,
        "value_type" => evidence.value_type,
        "confidence" => evidence.confidence,
        "respondent_kind" => evidence.respondent_kind,
        "inferred" => evidence.inferred,
        "recorded_at" => evidence.recorded_at&.utc&.iso8601(6),
        "metadata" => self.class.sort_keys_for_json(evidence.metadata.to_h.stringify_keys)
      }
    end

    def current_profile_hash
      return nil unless current_profile

      {
        "profile_version" => current_profile.profile_version,
        "generated_at" => current_profile.generated_at.utc.iso8601(6),
        "summary" => self.class.sort_keys_for_json(current_profile.summary.to_h)
      }
    end

    def profile_snapshot_hash
      return nil unless profile_snapshot

      {
        "id" => profile_snapshot.id,
        "generated_at" => profile_snapshot.generated_at.utc.iso8601(6),
        "summary" => self.class.sort_keys_for_json(profile_snapshot.summary.to_h)
      }
    end
  end
end
