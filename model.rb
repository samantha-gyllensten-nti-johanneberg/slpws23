#relevant functions
require 'bcrypt'
enable :sessions

def check_login(username, password)

    #perhaps add a length check to see entered stuff isnt too long, maybe should be seperate function or in app.rb

    session[:error_log_in] = false
    checkpassword = false

    db = connect_to_db_hash()

    #Compares username and password to already existing accounts
    checkusername = checkusername(username, db)

    if checkusername != [] #The username exists
        checkpassword = checkpassword(password, username, db) #sees if password is the same as registered to username
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
        session[:username] = username
        session[:log_in] = true

        id = find_user_id(username, db)

        redirect('/')
    end

end

def connect_to_db()
    db = SQLite3::Database.new("db/multipets.db")
    # db.results_as_hash = true #is this necessary?
end

def connect_to_db_hash()
    db = SQLite3::Database.new("db/multipets.db")
    db.results_as_hash = true
    return db
end

def checkusername(username, db)
    username = username
    checkuser = db.execute("SELECT * FROM users WHERE Username = ?", username)

    return  checkuser
end

def checkpassword(password, username, db)
    registered_password = db.execute("SELECT Password FROM users WHERE Username = ?", username)
    sleep 2

    if registered_password != []
        registered_password = registered_password[0][0]
    end

    if BCrypt::Password.new(registered_password) == password
        return true
    else
        return false
    end
end

# This broke again
def check_register(username, password, confirm_password)

    db = connect_to_db()

    checkusername = checkusername(username, db) #checks that username is free
    
    session[:error_reg_unik] = false
    session[:error_reg_password] = false

    if checkusername == [] && password == confirm_password #The name is not taken and the passwords match
        
        password_digest = BCrypt::Password.create(password)
        p password_digest

        session[:username] = username
        session[:log_in] = true

        register_user(username, password_digest, db)

        find_user_id(username, db)

    else
        if checkusername != [] #There is already a user by the same name
            session[:error_reg_unik] = true
        end
        if password != confirm_password #Not matching passwords
            session[:error_reg_password] = true
        end
    end
    
end

def register_user(username, password, db)
    #lägg till kontot i konto tabellen
    db.execute("INSERT INTO users (Username, Password) VALUES (?, ?)", username, password)
end

def find_user_id(username, db)
    #Checks the id of the user and assigns it to the session
    id = db.execute("SELECT Id FROM users WHERE Username LIKE ?", username).first
    p "find id check"
    p id['Id']
    session[:id] = id['Id']
    p session[:id]
end