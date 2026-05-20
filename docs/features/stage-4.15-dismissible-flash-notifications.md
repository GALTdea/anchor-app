# Stage 4.15 — Dismissible Flash Notifications

> Light brief. Improves transient success and error messaging without changing
> models, controllers, policies, migrations, or routes.

---

## Goal

Make success flash messages feel like lightweight confirmations by allowing
them to dismiss automatically after a few seconds and manually on click.

## Changes

Update the shared flash UI so parent-facing success notices such as "Child
profile was successfully created." do not remain on screen indefinitely.

Expected files:

- `app/views/shared/_flash.html.erb` — render flash messages inside a
  dismissible notification container, with success notices styled as success
  confirmations and alerts styled as errors.
- `app/views/layouts/application.html.erb` — wrap the shared flash render in a
  stable `flash` container if needed.
- `app/views/layouts/dashboard.html.erb` — wrap dashboard flash renders in the
  same stable `flash` container.
- `app/views/layouts/devise.html.erb` — keep auth-page flash behavior
  consistent.
- `app/javascript/controllers/flash_controller.js` — add a small Stimulus
  controller for auto-dismiss and manual close behavior.
- `app/helpers/application_helper.rb` — ensure Turbo stream flash rendering
  targets the shared flash partial and the stable `flash` container.
- Existing request or view specs as needed to cover rendered attributes and
  flash copy.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Flash keys remain `notice` for success and `alert` for warning/error.
- [ ] Use Tailwind CSS 4 + daisyUI 5 components.
- [ ] Do not introduce Bootstrap, Tabler, or daisyUI 4 class names.
- [ ] Prefer server-rendered HTML with Turbo/Stimulus for light interaction.
- [ ] Keep views DRY with partials.
- [ ] No custom CSS unless no Tailwind/daisyUI equivalent exists.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## Out of scope

- Changing controller redirect behavior or flash message wording across the app.
- Adding a global notification system backed by records or background jobs.
- Changing validation error blocks inside forms.
- Reworking page layouts beyond adding a stable flash target.
- Making alerts/errors disappear automatically.

## Open questions

> **Gate rule:** If any questions remain here, do not start building.

- None

## Steps

### Step 1 — Normalize the flash container

Render `shared/flash` inside a stable `id="flash"` target in application,
dashboard, and Devise layouts. Update `ApplicationHelper#render_flash_stream`
to render `shared/flash` into the same target so Turbo responses behave like
full-page flashes.

**Verify:** Search confirms one shared flash partial is used by active layouts
and `render_flash_stream` points to `shared/flash`.
**Revert:** Restore the previous layout render calls and helper partial target.

### Step 2 — Add dismissible flash markup

Update `app/views/shared/_flash.html.erb` so each flash message renders as a
daisyUI/Tailwind notification with:

- success styling for `notice`
- error styling for `alert`
- an accessible close button
- appropriate live-region semantics (`status`/polite for notices, `alert` for
  alerts)

Success copy should continue to render from the existing flash value, including
"Child profile was successfully created."

**Verify:** Rendered HTML includes the notice text, success styling, and a close
button; alert HTML includes error styling and remains accessible.
**Revert:** Restore the prior `shared/_flash.html.erb` contents.

### Step 3 — Add auto-dismiss behavior for notices

Add a Stimulus controller that removes `notice` flash messages after about 4
seconds. The controller should also support immediate dismissal from the close
button. Alerts should be manually dismissible but should not auto-dismiss.

Implementation notes:

- Use a data value such as `data-flash-auto-dismiss-value="true"` for notices.
- Use a timeout value around `4000` milliseconds.
- Clear timers on disconnect.
- Keep behavior small and dependency-free.

**Verify:** JavaScript controller test if the project has a JS test harness; if
not, manually verify in browser that a success notice disappears after the
delay and the close button removes either notice or alert immediately.
**Revert:** Remove the Stimulus controller and data attributes from the flash
partial.

### Step 4 — Verify the child profile creation path

Create or update focused coverage for the existing child profile create action
to confirm it still sets `flash[:notice]` and redirects normally. Then manually
exercise the create flow to confirm the success notification disappears and can
be closed.

**Verify:** `bundle exec rspec spec/requests/spaces/child_profiles_spec.rb`
and a browser check of the child profile creation flow.
**Revert:** Restore previous flash partial, layout target, helper, and
controller changes.

### Step 5 — Final verification

Run targeted Rails specs and RuboCop for changed Ruby files. If JavaScript was
changed without automated JS specs, document the manual browser verification in
the handoff.

**Verify:** `bundle exec rspec spec/requests/spaces/child_profiles_spec.rb`
and `bundle exec rubocop app/helpers/application_helper.rb`.
**Revert:** Revert the stage files listed in this brief.

---

## Status

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3
- [ ] Step 4
- [ ] Step 5

**Last updated:** 2026-05-19
**Handoff note:** Brief created only. Recommended behavior is success notices
auto-dismiss after about 4 seconds, all flash messages have an explicit close
button, and alerts remain until dismissed.
