## UI conventions
- Always use daisyUI semantic class as the base component
- Add Tailwind utilities for spacing, sizing, and layout
- Class order: layout → spacing → typography → color → state
- Never write custom CSS unless no Tailwind/daisyUI equivalent exists
- Dark mode via daisyUI data-theme attribute, not Tailwind dark: prefix

## Controller conventions  
- Always call authorize in every action (Pundit)
- Use before_action for shared authorization on resourceful controllers
- Flash keys: notice (success), alert (warning), error (failure)

## Form conventions
- Always use Rails form helpers (form_with)
- Never write raw HTML form tags
- daisyUI pattern: form-control wraps label + input + helper text

## Turbo conventions
- Prefer Turbo Frames for partial page updates
- Use Turbo Streams for multi-element updates from controller actions
- Add data-turbo-confirm for destructive actions

## UI Patterns

### Layout selection
- Public/marketing pages: layouts/application
- Authenticated pages: layouts/dashboard
  (set automatically by ApplicationController determine_layout based on user_signed_in?)
- Auth pages: layouts/devise
  (set automatically via devise_controller? check)

### Component hierarchy
1. daisyUI semantic class as base
   (btn, card, alert, input, select, etc.)
2. Tailwind utilities for spacing and layout
   (mt-4, flex, gap-3, max-w-2xl, etc.)
3. Never write custom CSS unless absolutely no Tailwind/daisyUI equivalent exists

### Flash messages
Use these flash keys consistently:
- flash[:notice] — success (renders alert-success)
- flash[:alert]  — warning/error (renders alert-error)
Rendered via shared/_flash.html.erb in all layouts.

### Pagination
Always use pagy. Never kaminari.
Controller: @pagy, @records = pagy(collection)
View: render "shared/pagination", pagy: @pagy
Pagy::Backend included in ApplicationController.
Pagy::Frontend included in ApplicationHelper.

### Page headers
Use the shared partial for consistency:
  render "shared/page_header",
    title: "Page Title",
    subtitle: "Optional subtitle"

### Forms
Always use Rails form helpers (form_with).
Never write raw HTML form tags.

Field pattern (daisyUI 5):
  <fieldset class="fieldset">
    <legend class="fieldset-legend">Section title</legend>
    <label class="label" for="field_id">Label text</label>
    <input id="field_id" class="input w-full"
           placeholder="..." />
  </fieldset>

Text input:    class="input w-full"
Select:        class="select w-full"
Textarea:      class="textarea w-full"
Submit button: class="btn btn-primary"
Cancel button: class="btn btn-ghost"

Full Rails example:
  <%= form_with model: @record do |f| %>
    <fieldset class="fieldset">
      <legend class="fieldset-legend">Details</legend>

      <label class="label" for="record_name">Name</label>
      <%= f.text_field :name,
            class: "input w-full",
            id: "record_name" %>

      <label class="label" for="record_status">
        Status
      </label>
      <%= f.select :status, status_options,
            {},
            class: "select w-full",
            id: "record_status" %>
    </fieldset>

    <div class="flex gap-2 mt-4">
      <%= f.submit "Save", class: "btn btn-primary" %>
      <%= link_to "Cancel", back_path,
            class: "btn btn-ghost" %>
    </div>
  <% end %>

## daisyUI 5 Class Migration Reference

When rebuilding deferred views (spaces/, users/) or writing new views, use daisyUI 5 class names. Reference table of breaking renames from v4:

| Old (daisyUI 4)      | New (daisyUI 5)        | Notes                        |
|----------------------|------------------------|------------------------------|
| input-bordered       | (remove)               | Border is default in v5      |
| select-bordered      | (remove)               | Border is default in v5      |
| textarea-bordered    | (remove)               | Border is default in v5      |
| file-input-bordered  | (remove)               | Border is default in v5      |
| form-control         | fieldset               | Use fieldset+legend+label    |
| label-text           | label                  | Standalone label element     |
| label-text-alt       | label                  | Use flex justify-between     |
| card-bordered       | card-border            | Renamed                      |
| card-compact         | card-sm                | Renamed                      |
| tabs-bordered        | tabs-border            | Renamed                      |
| tabs-lifted          | tabs-lift              | Renamed                      |
| tabs-boxed           | tabs-box               | Renamed                      |
| btn-group            | join + join-item       | Use join component           |
| input-group          | join + join-item       | Use join component           |
| menu active          | menu-active            | Renamed modifier             |
| menu disabled        | menu-disabled          | Renamed modifier             |
| avatar online        | avatar-online          | Renamed modifier             |
| table hover (class)  | hover:bg-base-300      | Use Tailwind utility instead |
| btm-nav              | dock                   | Component renamed            |

New form pattern in daisyUI 5:

  <fieldset class="fieldset">
    <legend class="fieldset-legend">Section</legend>
    <label class="label" for="field_id">Label</label>
    <input id="field_id" class="input w-full" />
  </fieldset>