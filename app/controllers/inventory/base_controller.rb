class Inventory::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_sala_admin!
  layout "inventory"
end
