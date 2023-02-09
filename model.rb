#relevant functions
require 'bcrypt'
enable :sessions

def check_login(username, password)
    # all of this still needs encrypting, but has some validation
    #perhaps add a length check to see entered stuff isnt too long, maybe should be seperate function or in app.rb
    session[:error_log_in] = false
    checkpassword = false

    db = connect_to_db_hash()
    p "database check in login"
    p db

    p "username and password check"
    p username
    p password

    #Compares username and password to already existing accounts
    checkusername = checkusername(username, db)
        p "checkusername result"
        p checkusername
    if checkusername != []
        checkpassword = checkpassword(password, username, db)
            p "checkpassword result"
            p checkpassword
    else
        session[:error_log_in] = true
        redirect('/users/')
    end

    if checkusername == [] || checkpassword == false
        session[:error_log_in] = true
        redirect('/users/')
        p "problem"
    else
        session[:username] = username
        p username
        session[:log_in] = true
        p session[:log_in]
        id = find_user_id(username, db)
        p "ID print"
        p id
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
    p "Inside checkusername"
    p checkuser
    # p checkuser[0][1]
    return  checkuser
end

def checkpassword(password, username, db)
    registered_password = db.execute("SELECT Password FROM users WHERE Username = ?", username)
    sleep 2
    p "ENCRYPTED FIRST"
    if registered_password != []
        registered_password = registered_password[0][0]
        p registered_password
    end
    p "ENCRYPTED"
    if BCrypt::Password.new(registered_password) == password
        p "this functions as intended"
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