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

  # Posición del registro en el orden de la lista: [n, total]
  def review_position(record)
    ids = record.class.order(:name, :id).pluck(:id)
    [ids.index(record.id).to_i + 1, ids.size]
  end

  def check_icon(level)
    {ok: "bi-check-circle-fill text-success", bad: "bi-x-circle-fill text-danger", warn: "bi-exclamation-triangle-fill text-warning", info: "bi-info-circle text-secondary"}.fetch(level)
  end
end
