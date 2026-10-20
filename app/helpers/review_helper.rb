module ReviewHelper
  def review_progress(model)
    by = Review.where(reviewable_type: model.name).group(:status).count
    total = model.count
    approved = by["approved"].to_i
    changes = by["needs_changes"].to_i
    {total: total, approved: approved, needs_changes: changes, pending: total - approved - changes}
  end

  def record_title(record)
    record.try(:seller_name) || record.name
  end
end
