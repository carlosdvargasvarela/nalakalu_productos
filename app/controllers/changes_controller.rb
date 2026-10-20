class ChangesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!

  def index
    @record = Reviewable::MODELS.include?(params[:type]) ? params[:type].constantize.find_by(id: params[:id]) : nil
    @batches = ChangeLog.batches(record: @record)
    @undoable = @batches.keys.index_with { ChangeLog.undoable?(_1) }
  end

  def undo
    n = ChangeLog.undo_batch!(params[:id], current_user)
    redirect_back_or_to changes_path, notice: "Listo: se deshicieron #{n} cambios."
  rescue ChangeLog::Conflict => e
    redirect_back_or_to changes_path, alert: e.message
  end
end
