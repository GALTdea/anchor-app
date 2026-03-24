 # Pagy configuration
 # See https://ddnexus.github.io/pagy/docs/api/pagy

 # Default items per page
 Pagy::DEFAULT[:limit] = 20

 # Enable the navegable_pages extra for daisyUI pagination UI
 require "pagy/extras/overflow"
 require "pagy/extras/metadata"

 # Handle overflow pages gracefully
 Pagy::DEFAULT[:overflow] = :last_page
