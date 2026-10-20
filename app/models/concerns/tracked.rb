# Registra creaciones, ediciones y borrados en ChangeLog (solo dentro de una petición web, ver ApplicationController).
module Tracked
  extend ActiveSupport::Concern

  included do
    after_create { ChangeLog.log(self, "create", nil, attributes) }
    after_update do
      changes = saved_changes.except("updated_at")
      ChangeLog.log(self, "update", changes.transform_values(&:first), changes.transform_values(&:last)) if changes.any?
    end
    after_destroy { ChangeLog.log(self, "destroy", attributes, nil) }
  end
end
