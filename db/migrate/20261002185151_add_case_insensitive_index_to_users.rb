class AddCaseInsensitiveIndexToUsers < ActiveRecord::Migration[8.0]
  def change
    remove_index :users, :email_address
    add_index :users, "lower(email_address)",
              unique: true,
              name: "index_users_on_lower_email_address"
  end
end
