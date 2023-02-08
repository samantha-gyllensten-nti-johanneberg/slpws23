require 'sqlite3'
require 'bcrypt'

username = "Kathrine"
pass = "ABCD"

db = SQLite3::Database.new("db/multipets.db")

result = db.execute("SELECT password FROM users WHERE username = ?", username)
result = result[0][0]
p result
p BCrypt::Password.new(result)
# password = result.first["password"]

if BCrypt::Password.new(result) == pass
    p "YEP"
end