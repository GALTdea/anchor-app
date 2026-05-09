# Stage 4.13 — Support Domain Illustrations

> Light brief. Adds neurodiversity-centered illustration assets for the
> parent-facing Support Guide domain system.

---

## Goal

Use five calm domain illustrations to make the child profile Support Guide feel
more parent-friendly, scannable, and emotionally supportive without making the
page decorative or less useful.

## Changes

Add the generated PNG illustrations as first-class Rails image assets and wire
them into the Support Guide domain mapping.

The illustrations represent the five parent-facing support domains:

1. Communication & Expression
2. Sensory Experience
3. Social Connection Style
4. Flexibility & Predictability
5. Body Signals & Daily Life

Store assets under:

```text
app/assets/images/support_domains/
```

Use stable, descriptive file names:

```text
communication_expression.png
sensory_experience.png
social_connection_style.png
flexibility_predictability.png
body_signals_daily_life.png
```

The images should be used as visual anchors for Support Guide domain cards,
especially in "What Anchor Understands Right Now" and, if useful, in compact
planning/support-style cards. They should not become a hero gallery or generic
decoration.

Domain-to-image mapping should live in presenter/helper code rather than being
hardcoded repeatedly in ERB.

## Visual Style

The uploaded illustrations share this intended style:

- minimal composition
- flat vector illustration
- soft ambient lighting/glow
- abstract symbolic metaphors instead of literal depictions
- white or ultra-clean backgrounds
- gradient-driven emotional color coding
- rounded, calm shapes
- emotionally supportive tone
- neurodiversity-friendly visual language
- wellness / modern health-tech aesthetic
- "Apple Health + Headspace + modern pediatric UX" energy

Implementation should preserve that tone by keeping image usage calm and
secondary to the guidance copy.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Use Rails asset pipeline conventions for app UI images.
- [ ] Keep assets in `app/assets/images/support_domains/`.
- [ ] Use Tailwind CSS 4 + daisyUI 5 components only.
- [ ] Do not add new models, migrations, routes, controllers, or policies.
- [ ] Do not change the onboarding assessment schema or domain data model.
- [ ] Do not use images as the only carrier of meaning; nearby text must name
      the support domain.
- [ ] Use empty `alt` text for decorative images when the card text already
      communicates the same meaning.
- [ ] Use descriptive `alt` text only if an image carries information not
      otherwise present in text.
- [ ] Keep images responsive and consistently sized so cards do not shift or
      feel visually noisy.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## UI Rules

- Images should usually render around 48-72px.
- Use `object-contain` and stable width/height classes.
- Do not crop images aggressively.
- Avoid heavy borders or framed illustration panels.
- Prefer a subtle image well only if it helps consistency, such as
  `bg-base-200/50`.
- Keep copy as the primary content.
- Do not show all five images as a decorative banner.
- Do not introduce a hero section.

## Domain Mapping

Use the five parent-facing domains as the presentation layer. Internally,
existing `dimension_key` and `concept_key` values remain unchanged.

Suggested mapping:

| Parent-facing domain | Asset | Internal examples |
|---|---|---|
| Communication & Expression | `communication_expression.png` | `communication.expressive`, `communication.receptive`, `communication.regulation`, `functional_communication`, `processing_delay`, `deescalation_strategies` |
| Sensory Experience | `sensory_experience.png` | `sensory.auditory`, `sensory.proprioception`, `sensory.coping_strategies`, `sensory_reactivity`, `body_awareness`, `sensory_regulation_tools` |
| Social Connection Style | `social_connection_style.png` | `social.engagement`, `social.interests`, `joint_attention`, `monotropism` |
| Flexibility & Predictability | `flexibility_predictability.png` | `regulation.transitions`, `regulation.routine`, `regulation.recovery`, `set_shifting`, `predictability_need`, `emotional_recovery_duration` |
| Body Signals & Daily Life | `body_signals_daily_life.png` | `daily_living.interoception`, `daily_living.motor`, `internal_awareness`, `coordination` |

The presenter should expose a domain key and image asset name for each rendered
insight. The view should not need to know internal dimensions or concepts.

## Acceptance Criteria

- [ ] The five uploaded PNGs are stored in
      `app/assets/images/support_domains/` with stable descriptive names.
- [ ] The Support Guide has a single domain-to-asset mapping in presenter/helper
      code.
- [ ] "What Anchor Understands Right Now" cards can render the relevant domain
      illustration when an insight has a mapped domain.
- [ ] Images render with stable dimensions and do not cause layout shifts.
- [ ] Images remain secondary to parent-facing guidance copy.
- [ ] The page still works when an image is missing or an insight has no mapped
      domain.
- [ ] No raw internal domain/dimension/concept names are introduced into the UI
      because of the image mapping.
- [ ] Existing child profile request specs still pass.
- [ ] Full RSpec and RuboCop pass.

## Out of scope

- No new image generation in this stage.
- No redesign of the full Support Guide layout beyond adding visual domain
  anchors.
- No database changes.
- No onboarding assessment taxonomy changes.
- No changes to recommendation generation.
- No large marketing-style hero illustration.
- No use of the images on unrelated pages unless a later brief adds that.

## Open questions

> **Gate rule:** If any questions remain here, do not start building.

- None

## Steps

### Step 1 — Add Image Assets

Copy the five PNG files into `app/assets/images/support_domains/` using the
stable file names listed in this brief.

**Verify:** `bin/rails runner 'puts Rails.application.assets.find_asset("support_domains/communication_expression.png").present?'` or equivalent asset lookup confirms files are available.
**Revert:** Remove the added image files.

### Step 2 — Add Domain Asset Mapping

Add a single mapping from parent-facing support domain keys to asset paths in
the Support Guide presenter/helper layer. Ensure insight objects expose the
domain key, domain title, and image asset when available.

**Verify:** Presenter specs confirm known domains return the expected image
asset names and unknown domains degrade gracefully.
**Revert:** Revert presenter/helper and spec changes.

### Step 3 — Render Images in Support Guide Cards

Update the Support Guide card markup, starting with "What Anchor Understands
Right Now", to render mapped illustrations beside or above the domain title.
Keep image sizes stable and responsive.

**Verify:** Request spec confirms the image asset paths appear for mapped
domains and that section copy still renders.
**Revert:** Revert view and request spec changes.

### Step 4 — Visual QA

Inspect the page at desktop and mobile widths. Confirm images are visible,
properly sized, not cropped, not overpowering the text, and not creating layout
shifts or overlapping content.

**Verify:** Browser screenshot or manual inspection at desktop and mobile
viewports.
**Revert:** Revert image rendering styles if the assets hurt readability.

### Step 5 — Final Verification

Run targeted specs, then full RSpec and RuboCop.

**Verify:** `bundle exec rspec` and `bundle exec rubocop`
**Revert:** Revert the stage changes if final verification cannot be made green
in the session.

---

## Status

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3
- [ ] Step 4
- [ ] Step 5

**Last updated:** 2026-05-08
**Handoff note:** Brief created. Next implementation session should place the
uploaded PNGs in `app/assets/images/support_domains/`, then wire them through a
single Support Guide domain asset mapping.
