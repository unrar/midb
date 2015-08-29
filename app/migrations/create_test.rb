require 'rmvc'
m = RMVC::Migration.new("test")
# Insert migration commands here
m.drop_table("test")
m.create_table("test")
m.add_column("test", "tname", :text)
m.add_column("test", "tage", :num)

m.insert("test", ["tname", "tage"], ["joselo", 13])
m.insert("test", ["tname", "tage"], ["josefina", 43])
