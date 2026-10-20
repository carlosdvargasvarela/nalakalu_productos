class Current < ActiveSupport::CurrentAttributes
  attribute :user, :batch_id, :label, :skip_log
end
