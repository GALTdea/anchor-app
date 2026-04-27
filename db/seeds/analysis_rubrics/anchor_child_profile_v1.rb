# frozen_string_literal: true

# Published rubric: append-only. New behavior requires a new `version` (and new row).
# Deterministic evaluators read `schema` — keep keys string-based for JSONB stability.

unless defined?(ANCHOR_CHILD_PROFILE_V1_RUBRIC_SCHEMA)
  ANCHOR_CHILD_PROFILE_V1_RUBRIC_SCHEMA = {
    "version" => 1,
    "engine" => "deterministic_v1",
    "wording" => {
      "use_terms" => [
        "profile pattern",
        "support signal",
        "what may be happening",
        "what may help",
        "based on your answers and saved observations",
        "confidence"
      ],
      "avoid_terms" => [
        "diagnosis",
        "severity score",
        "autism score",
        "deficit",
        "clinically indicates"
      ],
      "stance" => "Support-oriented, non-clinical, hypotheses not determinations."
    },
    "domains" => [
      {
        "key" => "communication",
        "title" => "Communication",
        "dimension_key_prefixes" => [ "communication." ],
        "accepted_concept_keys" => [ "*" ],
        "scoring" => {
          "scale" => "0.0_to_1.0",
          "higher_is_more_support" => true,
          "aggregation" => "weighted_mean_confidence_by_evidence"
        },
        "confidence" => {
          "base_cap" => 0.9,
          "min_evidence_rows" => 1,
          "per_evidence_cap_delta" => 0.02,
          "low_confidence_if_below" => 0.35
        },
        "evidence_minimums" => {
          "min_rows" => 1,
          "min_sum_confidence" => 0.2
        },
        "parent_labels" => {
          "anchor" => "How your child gets needs across and takes language in"
        },
        "support_categories" => [ "communication" ],
        "safety" => {
          "forbid_diagnostic" => true,
          "framing" => "observed communication patterns and support signals"
        }
      },
      {
        "key" => "social_connection",
        "title" => "Social connection",
        "dimension_key_prefixes" => [ "social." ],
        "accepted_concept_keys" => [ "*" ],
        "scoring" => {
          "scale" => "0.0_to_1.0",
          "higher_is_more_support" => true,
          "aggregation" => "weighted_mean_confidence_by_evidence"
        },
        "confidence" => {
          "base_cap" => 0.9,
          "min_evidence_rows" => 1,
          "per_evidence_cap_delta" => 0.02,
          "low_confidence_if_below" => 0.35
        },
        "evidence_minimums" => {
          "min_rows" => 1,
          "min_sum_confidence" => 0.2
        },
        "parent_labels" => {
          "anchor" => "How your child shares joy, connects, and uses interests"
        },
        "support_categories" => [ "social_connection" ],
        "safety" => { "forbid_diagnostic" => true, "framing" => "connection and interaction patterns" }
      },
      {
        "key" => "flexibility",
        "title" => "Flexibility and change",
        "dimension_key_prefixes" => [ "behavior.", "regulation.routine", "regulation.transitions" ],
        "accepted_concept_keys" => [ "*" ],
        "scoring" => {
          "scale" => "0.0_to_1.0",
          "higher_is_more_support" => true,
          "aggregation" => "weighted_mean_confidence_by_evidence"
        },
        "confidence" => {
          "base_cap" => 0.88,
          "min_evidence_rows" => 1,
          "per_evidence_cap_delta" => 0.02,
          "low_confidence_if_below" => 0.35
        },
        "evidence_minimums" => {
          "min_rows" => 1,
          "min_sum_confidence" => 0.2
        },
        "parent_labels" => {
          "anchor" => "How your child handles change, routines, and mental flexibility"
        },
        "support_categories" => [ "flexibility", "transitions" ],
        "safety" => { "forbid_diagnostic" => true, "framing" => "routines, transitions, and rigidity as support signals" }
      },
      {
        "key" => "sensory_experience",
        "title" => "Sensory experience",
        "dimension_key_prefixes" => [ "sensory." ],
        "accepted_concept_keys" => [ "*" ],
        "scoring" => {
          "scale" => "0.0_to_1.0",
          "higher_is_more_support" => true,
          "aggregation" => "weighted_mean_confidence_by_evidence"
        },
        "confidence" => {
          "base_cap" => 0.9,
          "min_evidence_rows" => 1,
          "per_evidence_cap_delta" => 0.02,
          "low_confidence_if_below" => 0.35
        },
        "evidence_minimums" => {
          "min_rows" => 1,
          "min_sum_confidence" => 0.2
        },
        "parent_labels" => {
          "anchor" => "What tends to energize, soothe, or overload your child"
        },
        "support_categories" => [ "sensory" ],
        "safety" => { "forbid_diagnostic" => true, "framing" => "sensory load and comfort patterns" }
      },
      {
        "key" => "regulation",
        "title" => "Regulation",
        "dimension_key_prefixes" => [ "regulation." ],
        "accepted_concept_keys" => [ "*" ],
        "scoring" => {
          "scale" => "0.0_to_1.0",
          "higher_is_more_support" => true,
          "aggregation" => "weighted_mean_confidence_by_evidence"
        },
        "confidence" => {
          "base_cap" => 0.9,
          "min_evidence_rows" => 1,
          "per_evidence_cap_delta" => 0.02,
          "low_confidence_if_below" => 0.35
        },
        "evidence_minimums" => {
          "min_rows" => 1,
          "min_sum_confidence" => 0.2
        },
        "parent_labels" => {
          "anchor" => "How your child recovers, escalates, and meets demands"
        },
        "support_categories" => [ "regulation" ],
        "safety" => { "forbid_diagnostic" => true, "framing" => "regulation and stress response patterns" }
      },
      {
        "key" => "daily_life",
        "title" => "Daily life",
        "dimension_key_prefixes" => [ "daily_living.", "adaptive." ],
        "accepted_concept_keys" => [ "*" ],
        "scoring" => {
          "scale" => "0.0_to_1.0",
          "higher_is_more_support" => true,
          "aggregation" => "weighted_mean_confidence_by_evidence"
        },
        "confidence" => {
          "base_cap" => 0.88,
          "min_evidence_rows" => 1,
          "per_evidence_cap_delta" => 0.02,
          "low_confidence_if_below" => 0.35
        },
        "evidence_minimums" => {
          "min_rows" => 1,
          "min_sum_confidence" => 0.2
        },
        "parent_labels" => {
          "anchor" => "Everyday skills, self-care, and independence in routines"
        },
        "support_categories" => [ "daily_life", "adaptive" ],
        "safety" => { "forbid_diagnostic" => true, "framing" => "day-to-day functioning patterns" }
      },
      {
        "key" => "strengths_and_motivators",
        "title" => "Strengths and motivators",
        "dimension_key_prefixes" => [ "strengths." ],
        "accepted_concept_keys" => [ "*" ],
        "scoring" => {
          "scale" => "0.0_to_1.0",
          "higher_is_more_support" => false,
          "note" => "Strengths: higher score = stronger strengths signal (interpret in evaluator).",
          "aggregation" => "weighted_mean_confidence_by_evidence"
        },
        "confidence" => {
          "base_cap" => 0.85,
          "min_evidence_rows" => 1,
          "per_evidence_cap_delta" => 0.02,
          "low_confidence_if_below" => 0.3
        },
        "evidence_minimums" => {
          "min_rows" => 1,
          "min_sum_confidence" => 0.15
        },
        "parent_labels" => {
          "anchor" => "What your child is drawn to and what already works for them"
        },
        "support_categories" => [ "strengths" ],
        "safety" => { "forbid_diagnostic" => true, "framing" => "strengths and motivators, not 'splinter skills' as deficit" }
      },
      {
        "key" => "family_priorities",
        "title" => "Family priorities",
        "dimension_key_prefixes" => [ "priorities.", "context." ],
        "accepted_concept_keys" => [ "*" ],
        "scoring" => {
          "scale" => "0.0_to_1.0",
          "higher_is_more_support" => true,
          "aggregation" => "latest_evidence_or_weighted",
          "note" => "Parent goals: emphasize alignment, not performance."
        },
        "confidence" => {
          "base_cap" => 0.9,
          "min_evidence_rows" => 1,
          "per_evidence_cap_delta" => 0.03,
          "low_confidence_if_below" => 0.3
        },
        "evidence_minimums" => {
          "min_rows" => 1,
          "min_sum_confidence" => 0.15
        },
        "parent_labels" => {
          "anchor" => "What you want to prioritize next for your child and family"
        },
        "support_categories" => [ "family_goals" ],
        "safety" => { "forbid_diagnostic" => true, "framing" => "caregiver-stated goals and context" }
      }
    ]
  }.freeze
end

rubric = AnalysisRubric.find_or_initialize_by(rubric_key: "anchor_child_profile_v1", version: 1)
if rubric.new_record? || !rubric.published?
  rubric.assign_attributes(
    name: "Anchor child profile",
    description: "Deterministic, evidence-backed reading of profile signals across " \
                 "Anchor's core domains. Uses ProfileEvidence and profile dimensions; " \
                 "not a clinical or diagnostic output.",
    status: :published,
    published_at: Time.find_zone!("UTC").parse("2026-04-27T00:00:00Z"),
    schema: ANCHOR_CHILD_PROFILE_V1_RUBRIC_SCHEMA.deep_dup
  )
  rubric.save!
end
