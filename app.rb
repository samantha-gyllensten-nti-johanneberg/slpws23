#main controller
require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'
require_relative 'model' # should work, double check

enable :sessions

def userresult(db)
    id = session[:id]
    p id
    userresult = db.execute("SELECT * FROM users WHERE Id LIKE ?", id).first
    return userresult
end

get('/') do
    p "Session login check"
    p session[:log_in]
    if session[:log_in]
        db = connect_to_db_hash()
        p db
        
        userresult = userresult(db)
        p userresult
        slim(:"index", locals:{users:userresult})
    else
        slim(:"index")
    end
end

# Users

#could users be restful:d??
get('/users/') do
    if session[:log_in]
        db = connect_to_db_hash()
        
        userresult = userresult(db)
        slim(:"users/index", locals:{users:userresult})
    else
        slim(:"users/index")
    end
end

get('/users/new') do
    slim(:"users/new")
end

get('/users/:id') do
    id = params[:id].to_i
    db = connect_to_db_hash()
    
    userresult = userresult(db)
    if userresult['Admin'] == "Admin"
        result = db.execute("SELECT Id, Username, Admin FROM users")
        slim(:"users/show", locals:{users:userresult, userlist:result})
    else
        slim(:"users/show", locals:{users:userresult})
    end
end

get('/users/:id/edit') do
    id = params[:id].to_i
    db = connect_to_db_hash()

    userresult = userresult(db)

    slim(:"users/edit", locals:{users:userresult})
end

#could login and logout possibly be restfuled for post?
post('/log_in') do
    username = params[:username]
    password = params[:password]
    p "Step 1:"
    p username
    p password

    check_login = check_login(username, password)
    p "Step 2:"
    p check_login
end

post('/log_out') do
    session.destroy
    redirect('/')
end

post('/register_user') do
    username = params[:username]
    password = params[:password1]
    confirm_password = params[:password2]

    check_register(username, password, confirm_password)

    redirect('/') #THIS NEEDS MOVING
end

post('/password_check/:id') do
    session[:password_checked_error] = false
    session[:password_checked] = false
    # These might need to be placed elsewhere to make sure it doesnt permanently save

    id = params[:id]
    password = params[:password]
    db = connect_to_db_hash

    user = db.execute("SELECT * FROM users WHERE Id = ?", id).first
    username = user['Username']
        # Needs to do checks to see that password is correct first, safety whoop whoop, use the already made function, just needs a form on edit (maybe use sessions?)

    check = checkpassword(password, username, db)
    if check
        session[:password_checked] = true
    else
        session[:password_checked_error] = true
    end

    redirect('/users/:id/edit')

end

post('/users/:id/update') do
    session[:password_checked] = false
    id = params[:id]
    db = connect_to_db_hash

    username = params[:username]
    username_check = session[:username]
    password = params[:password]

    checkpassword = checkpassword(password, username_check, db)    
    if checkpassword
        session[:password_checked] = true
    end

    if params[:username] != nil
        db.execute("UPDATE users SET Username = ? WHERE Id = ?", username, id)
    end
    if params[:password] != ""
        password = BCrypt::Password.create(password)
        # encrypts password
        db.execute("UPDATE users SET Password = ? WHERE Id = ?", password, id)
    end

    redirect('/users/')
end

# Monsters

get('/monsters/') do
    if session[:log_in]
        id = session[:id] #does this work logged out?
        db = connect_to_db_hash()
        
        userresult = userresult(db)
        if userresult['Admin'] == "Admin"
            result = db.execute("SELECT * FROM monsters")
            p result
            p "Lookie"
        else
            result = db.execute("SELECT * FROM monsters WHERE UserId = ?", id)
        end
        slim(:"monsters/index", locals:{monsters:result, users:userresult})
    else
        slim(:"monsters/index")
    end
end

# why does this code break if moved after :id???
get('/monsters/new') do
    db = connect_to_db_hash()
    userresult = userresult(db)

    slim(:"monsters/new", locals:{users:userresult})
end

get('/monsters/:id') do
    id = params[:id].to_i
    db = connect_to_db_hash()
    
    userresult = userresult(db)
    result = db.execute("SELECT * FROM monsters WHERE Id = ?", id).first

    slim(:"monsters/show", locals:{monsters:result, users:userresult})
end

get('/monsters/:id/edit') do
    id = params[:id].to_i
    db = connect_to_db_hash()
    
    userresult = userresult(db)
    result = db.execute("SELECT * FROM monsters WHERE Id = ?", id).first

    slim(:"monsters/edit", locals:{monsters:result, users:userresult})
end

post('/monsters') do
    name = params[:name]
    age = params[:age]
    type1 = params[:type1]
    type2 = params[:type2]

    redirect('/monsters/')
end

post('/monsters/:id/update') do
    id = params[:id]
    db = connect_to_db_hash

    name = params[:name]

    if params[:name] != ""
        db.execute("UPDATE monsters SET Name = ? WHERE Id = ?", name, id)
    end

    redirect('/monsters/')
end

# Helpers

# helpers do
    
# end
