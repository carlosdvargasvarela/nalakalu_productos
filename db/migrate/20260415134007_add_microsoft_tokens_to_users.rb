class AddMicrosoftTokensToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :microsoft_provider, :string
    add_column :users, :microsoft_uid, :string
    add_column :users, :microsoft_token, :string
    add_column :users, :microsoft_refresh_token, :string
    add_column :users, :microsoft_token_expires_at, :datetime
  end
end
