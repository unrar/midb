require 'rmvc'
m = RMVC::Migration.new("test")
# Insert migration commands here
m.drop_table("confidential")
m.create_table("confidential")
m.add_column("confidential", "uid", :num)
m.add_column("confidential", "password", :text)

m.insert("confidential", ["uid", "password"], [2, "socpatit"])
m.insert("confidential", ["uid", "password"], [1, "lajosefaeslajefa"])