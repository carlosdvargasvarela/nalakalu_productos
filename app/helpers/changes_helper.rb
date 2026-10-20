module ChangesHelper
  JOIN_TYPES = %w[Compatibility ProductVariantRule FamilyVariantRule SupplierLink].freeze

  def batch_main(rows)
    rows.find { !JOIN_TYPES.include?(_1.record_type) } || rows.first
  end

  def change_detail(row)
    case row.action
    when "update" then (row.before_data || {}).map { |k, v| "#{k}: #{v.inspect} → #{row.after_data[k].inspect}" }.join(" · ")
    when "create" then "creado"
    else "eliminado"
    end
  end
end
