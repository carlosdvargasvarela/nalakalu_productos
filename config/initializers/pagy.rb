# frozen_string_literal: true

# Pagy 43.x
# https://ddnexus.github.io/pagy/toolbox/configuration/initializer/

Pagy::OPTIONS[:limit] = 150
# opcional:
# Pagy::OPTIONS[:max_limit] = 300

Pagy::OPTIONS.freeze
