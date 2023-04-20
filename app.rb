#main controller
require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'
require_relative 'model' # should work, double check

enable :sessions

# use before blocks to check if admin, and if logged in (if not, make sure to reroute to index to avoid error messages)

def userresult(db)
    id = session[:id]
    p id
    userresult = db.execute("SELECT * FROM users WHERE Id = ?", id).first
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
    p "id for get"
    p id
    db = connect_to_db_hash()

    userresult = userresult(db)
    p "userresult check"
    p userresult['Id']
    if userresult['Id'] != id
        userresult['Id'] = id
    end

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
    p id
    p "lasre"
    password = params[:password]
    username = params[:username]
    db = connect_to_db_hash


    user = db.execute("SELECT * FROM users WHERE Id = ?", id).first
    p user
    p username == user['Username']
    if username == user['Username']
    
        check = checkpassword(password, username, db)
        p check
        # could this in theory be moved into the function?
        if check
            session[:password_checked] = true
        else
            session[:password_checked_error] = true
        end
    else
        session[:password_checked_error] = true
    end

    p session[:password_checked_error]
    # id = db.execute("SELECT Id FROM users WHERE id")
    redirect("/users/#{id}/edit") #currently the id will redirect wrong if an admin tries to edit

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
        id = session[:id]
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

    resulttype = db.execute("SELECT * FROM monsters_monstertypes_rel INNER JOIN monstertypes ON monsters_monstertypes_rel.TypeId = monstertypes.Id INNER JOIN monstertypes_foods_rel ON monsters_monstertypes_rel.TypeId = monstertypes_foods_rel.TypeId WHERE MonsterId = ?", id)

    # OBS!! Still needs a popup for feeding and code for that
    # Compatable foods is stored in resulttype for now, is this optimal? 
    # The foods still need to be called on when food is selected

    slim(:"monsters/show", locals:{monsters:result, types:resulttype, users:userresult})
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
    desc = params[:desc]
    type1 = params[:type1]
    type2 = params[:type2]
    userid = session[:id]
    fed = "No"

    db = connect_to_db_hash
    db.execute("INSERT INTO monsters (Name, Age, Fed, UserId, Description) VALUES (?, ?, ?, ?, ?)", name, age, fed, userid, desc)

    redirect('/monsters/')
end

post('/monsters/:id/update') do
    # check user owns pets
    # check if user is admin
    id = params[:id]
    db = connect_to_db_hash

    name = params[:name]
    age = params[:age]
    desc = params[:desc]
    userid = params[:id]

    if params[:name] != ""
        db.execute("UPDATE monsters SET Name = ? WHERE Id = ?", name, id)
    end
    if params[:age] != ""
        db.execute("UPDATE monsters SET Age = ? WHERE Id = ?", age, id)
    end
    if params[:desc] != ""
        db.execute("UPDATE monsters SET Description = ? WHERE Id = ?", desc, id)
    end
    if params[:id] != ""
        db.execute("UPDATE monsters SET UserId = ? WHERE Id = ?", userid, id)
    end

    redirect('/monsters/')
end

# Foods

get('/foods/') do
    if session[:log_in]
        id = session[:id]
        db = connect_to_db_hash()
        
        userresult = userresult(db)
        if userresult['Admin'] == "Admin"
            result = db.execute("SELECT * FROM foods")
            p result
            p "Lookie"
        else
            result = db.execute("SELECT * FROM foods WHERE UserId = ?", id)
        end
        slim(:"foods/index", locals:{foods:result, users:userresult})
    else
        slim(:"foods/index")
    end
end

get('/foods/new') do
    db = connect_to_db_hash()
    userresult = userresult(db)

    slim(:"foods/new", locals:{users:userresult})
end

get('/foods/:id') do
    id = params[:id].to_i
    db = connect_to_db_hash()
    
    userresult = userresult(db)
    result = db.execute("SELECT * FROM foods WHERE Id = ?", id).first

    slim(:"foods/show", locals:{foods:result, users:userresult})
end

get('/foods/:id/edit') do
    id = params[:id].to_i
    db = connect_to_db_hash()
    
    userresult = userresult(db)
    result = db.execute("SELECT * FROM foods WHERE Id = ?", id).first

    slim(:"foods/edit", locals:{foods:result, users:userresult})
end

post('/foods') do
    name = params[:name]
    desc = params[:desc]
    # type1 = params[:type1]
    # type2 = params[:type2]

    db = connect_to_db_hash
    db.execute("INSERT INTO foods (Name, Description) VALUES (?, ?)", name, desc)

    redirect('/foods/')
end

post('/foods/:id/update') do
    id = params[:id]
    db = connect_to_db_hash

    name = params[:name]
    desc = params[:desc]

    if params[:name] != ""
        db.execute("UPDATE foods SET Name = ? WHERE Id = ?", name, id)
    end
    if params[:desc] != ""
        db.execute("UPDATE foods SET Description = ? WHERE Id = ?", desc, id)
    end

    redirect('/foods/')
end

# Toys

get('/toys/') do
    if session[:log_in]
        id = session[:id]
        db = connect_to_db_hash()
        
        userresult = userresult(db)
        if userresult['Admin'] == "Admin"
            result = db.execute("SELECT * FROM toys")
            p result
            p "Lookie"
        else
            result = db.execute("SELECT * FROM toys WHERE UserId = ?", id)
        end
        slim(:"toys/index", locals:{toys:result, users:userresult})
    else
        slim(:"toys/index")
    end
end

get('/toys/new') do
    db = connect_to_db_hash()
    userresult = userresult(db)

    slim(:"toys/new", locals:{users:userresult})
end

get('/toys/:id') do
    id = params[:id].to_i
    db = connect_to_db_hash()
    
    userresult = userresult(db)
    result = db.execute("SELECT * FROM toys WHERE Id = ?", id).first

    slim(:"toys/show", locals:{toys:result, users:userresult})
end

get('/toys/:id/edit') do
    id = params[:id].to_i
    db = connect_to_db_hash()
    
    userresult = userresult(db)
    result = db.execute("SELECT * FROM toys WHERE Id = ?", id).first

    slim(:"toys/edit", locals:{toys:result, users:userresult})
end

post('/toys') do
    name = params[:name]
    desc = params[:desc]
    type = params[:type]

    db = connect_to_db_hash
    db.execute("INSERT INTO toys (Name, Description, AnimalType) VALUES (?, ?, ?)", name, desc, type)

    redirect('/toys/')
end

post('/toys/:id/update') do
    id = params[:id]
    name = params[:name]
    desc = params[:desc]
    type = params[:type]
    db = connect_to_db_hash

    if params[:name] != ""
        db.execute("UPDATE toys SET Name = ? WHERE Id = ?", name, id)
    elsif params[:desc] != ""
        db.execute("UPDATE toys SET Descrpition = ? WHERE Id = ?", desc, id)
    elsif params[:type] != ""
        db.execute("UPDATE toys SET AnimalType = ? WHERE Id = ?", type, id)
    end

    redirect('/toys/')
end

# market

get('/market/') do
    db = connect_to_db_hash()
    # result = db.execute("SELECT * FROM market INNER JOIN monsters ON monsters.Id = market.MonsterId INNER JOIN toys ON toys.Id = market.ToyId INNER JOIN foods ON foods.Id = market.FoodId")
    # p "inner join result"
    # p result

    userresult = userresult(db) 
    # this could probably be turned into a before block so as to clean the code

    slim(:"market/index", locals:{users:userresult})
end


# Helpers

# helpers do
    
# end
