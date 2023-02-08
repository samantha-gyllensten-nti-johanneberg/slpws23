#main controller
require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'
require_relative 'model' # should work, double check

enable :sessions

get('/') do
    if session[:log_in]
        id = session[:id] #does this work logged out?
        db = connect_to_db_hash()
        
        result = db.execute("SELECT * FROM users WHERE Id = ?", id).first
        slim(:"index", locals:{users:result})
    else
        slim(:"index")
    end
end

# Users

#could users be restful:d??
get('/users/') do
    if session[:log_in]
        id = session[:id] #does this work logged out?
        db = connect_to_db_hash()
        
        result = db.execute("SELECT * FROM users WHERE Id = ?", id).first
        slim(:"users/index", locals:{users:result})
    else
        slim(:"users/index")
    end
end

get('/users/:id') do
    id = params[:id].to_i
    db = connect_to_db_hash()
    
    result = db.execute("SELECT * FROM users WHERE Id = ?", id).first
    p result
    if result['Admin'] == "Admin"
        db2 = connect_to_db_hash()
        result2 = db2.execute("SELECT Id, Username, Admin FROM users")
        p "RESULT 2"
        p result2
        slim(:"users/show", locals:{users:result, userlist:result2})
    else
        slim(:"users/show", locals:{users:result})
    end
end

get('/users/:id/edit') do
    id = params[:id].to_i
    slim(:"users/edit")
end

get('/users/new') do
    slim(:"users/new")
end

#could login and logout possibly be restfuled for post?
post('/log_in') do
    username = params[:username]
    password = params[:password]

    check_login(username, password)
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


# Monsters

get('/monsters/') do
    if session[:log_in]
        id = session[:id] #does this work logged out?
        db = connect_to_db_hash()
        
        result = db.execute("SELECT * FROM users WHERE Id = ?", id).first
        resultmon = db.execute("SELECT * FROM monsters WHERE UserId = ?", id)
        p resultmon
        slim(:"monsters/index", locals:{monsters:resultmon, users:result})
    else
        slim(:"monsters/index")
    end
end

get('/monsters/:id') do
    id = params[:id].to_i
    db = connect_to_db_hash()
    
    result = db.execute("SELECT * FROM users WHERE Id = ?", id).first
    p result
    if result['Admin'] == "Admin"
        db2 = connect_to_db_hash()
        result2 = db2.execute("SELECT Id, Username, Admin FROM users")
        p "RESULT 2"
        p result2
        slim(:"users/show", locals:{users:result, userlist:result2})
    else
        slim(:"users/show", locals:{users:result})
    end
end

get('/monsters/:id/edit') do
    id = params[:id].to_i
    slim(:"users/edit")
end

get('/monsters/new') do
    slim(:"users/new")
end
