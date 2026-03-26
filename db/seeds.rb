# db/seeds.rb
# Creates minimal seed data for development.
# Safe to run multiple times (find_or_create_by).

puts "Seeding database..."

# --- Roles (create before users/spaces that reference them) ---

all_true = Role::AVAILABLE_PERMISSIONS.index_with { "true" }

owner_role = Roles::Common.find_or_create_by!(name: "Owner") do |r|
  r.value = "owner"
  r.permissions = all_true
end

Roles::Common.find_or_create_by!(name: "Caregiver") do |r|
  r.value = "caregiver"
  r.permissions = all_true.merge(
    "create_space" => "false",
    "update_space" => "false",
    "delete_space" => "false",
    "manage_collaborators" => "false"
  )
end

Roles::Common.find_or_create_by!(name: "Collaborator") do |r|
  r.value = "collaborator"
  r.permissions = all_true.merge(
    "create_user" => "false",
    "update_user" => "false",
    "delete_user" => "false",
    "create_space" => "false",
    "update_space" => "false",
    "delete_space" => "false",
    "update_child_profile" => "false",
    "delete_child_profile" => "false",
    "manage_collaborators" => "false"
  )
end

puts "  roles: #{Roles::Common.pluck(:name).join(', ')}"

# --- Users ---

admin = User.find_or_create_by!(email: "admin@example.com") do |u|
  u.first_name = "Admin"
  u.last_name  = "User"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.admin = true
end
puts "  admin user: #{admin.email}"

user = User.find_or_create_by!(email: "user@example.com") do |u|
  u.first_name = "Regular"
  u.last_name  = "User"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.admin = false
end
puts "  regular user: #{user.email}"

# --- Space + membership ---

space = Space.find_or_create_by!(name: "Demo Family") do |s|
  s.status = :active
end
puts "  space: #{space.name}"

UserRole.find_or_create_by!(user: admin, space: space) do |ur|
  ur.role = owner_role
end
puts "  admin assigned owner role in #{space.name}"

puts ""
puts "Done! Seed data loaded."
puts ""
puts "Login credentials:"
puts "  Admin — admin@example.com / password123"
puts "  User  — user@example.com / password123"
