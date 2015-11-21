# Just some methods to hook to the API
def announce_entries(n)
  puts ">> #{n} entries have been returned via JSON."
end
def lol_im_hooked(n)
  puts ">> HAHA im hooked duh"
end
def format(field, what)
  if field == "age"
    "#{what} years old"
  else
    what
  end
end