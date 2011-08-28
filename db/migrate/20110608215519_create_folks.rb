class CreateFolks < ActiveRecord::Migration
  def self.up
    create_table :folks do |t|
      t.string :name

      t.timestamps
    end
  end

  def self.down
    drop_table :folks
  end
end
