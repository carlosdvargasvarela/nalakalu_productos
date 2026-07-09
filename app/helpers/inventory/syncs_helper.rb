require "digest"

module Inventory::SyncsHelper
  # order_number puede tener "/", espacios o ser nil (movimientos manuales) —
  # hashearlo da un id de DOM estable y válido para Turbo Streams.
  def dom_id_for_order_group(order_number)
    "order_group_#{Digest::MD5.hexdigest(order_number.to_s)}"
  end
end
