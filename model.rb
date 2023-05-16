#relevant functions
require 'sinatra'
require 'slim'
require 'sinatra/reloader'
# require 'sinatra/flash'
require 'sqlite3'
require 'bcrypt'
enable :sessions

def userresult()
    id = session[:id]
    p "db check"
    p $db
    userresult = $db.execute("SELECT * FROM users WHERE Id = ?", id).first

    return userresult
end

def check_login(username, password)

    #perhaps add a length check to see entered stuff isnt too long, maybe should be seperate function or in app.rb

    session[:error_log_in] = false
    checkpassword = false

    #Compares username and password to already existing accounts
    checkusername = checkusername(username)

    if checkusername != [] #The username exists
        checkpassword = checkpassword(password, username) #sees if password is the same as registered to username
    else
        #The username does not exist, error
        session[:error_log_in] = true
        redirect('/users/')
    end

    if checkusername == [] || checkpassword == false #If the username does not exist (added to niot break code), or the password does not match
        # Username or password is wrong, error
        session[:error_log_in] = true
        redirect('/users/')
    else
        # Logs user in
        session[:log_in] = true

        id = find_user_id(username)

        redirect('/')
    end

end

def connect_to_db_hash()
    db = SQLite3::Database.new("db/multipets.db")
    db.results_as_hash = true
    return db
end

def checkusername(username)
    username = username
    checkuser = $db.execute("SELECT * FROM users WHERE Username = ?", username)

    return checkuser
end

def checkpassword(password, username)
    registered_password = $db.execute("SELECT Password FROM users WHERE Username = ?", username)

    if registered_password != []
        registered_password = registered_password[0][0]
    end

    if BCrypt::Password.new(registered_password) == password
        return true
    else
        return false
    end
end

def check_register(username, password, confirm_password)

    checkusername = checkusername(username) #checks that username is free
    
    session[:error_reg_unik] = false
    session[:error_reg_password] = false

    if checkusername == [] && password == confirm_password #The name is not taken and the passwords match
        
        password_digest = BCrypt::Password.create(password)

        register_user(username, password_digest)

        find_user_id(username)

    elsif checkusername != [] #There is already a user by the same name
            session[:error_reg_unik] = true
    elsif password != confirm_password #Not matching passwords
            session[:error_reg_password] = true
    end
    
end

def register_user(username, password)
    #lägg till kontot i konto tabellen
    $db.execute("INSERT INTO users (Username, Password) VALUES (?, ?)", username, password)
end

def find_user_id(username)
    #Checks the id of the user and assigns it to the session
    id = $db.execute("SELECT Id FROM users WHERE Username LIKE ?", username).first
    session[:id] = id['Id']
end

# def update_user(username, password)
#     db = connect_to_db_hash

#     if username != nil
#         db.execute("UPDATE users SET Username = ? WHERE Id = ?", username, id)
#     end

#     if password != ""
#         password = BCrypt::Password.create(password)
#         db.execute("UPDATE users SET Password = ? WHERE Id = ?", password, id)
#     end
# end