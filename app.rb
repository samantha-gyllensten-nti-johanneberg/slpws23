#main controller
require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'
require_relative 'model'

enable :sessions

# Have to be in app.rb
$db = connect_to_db_hash()
# Required for CASCADE SQL functions
$db.execute("PRAGMA foreign_keys = ON")

# use before blocks to check if admin, and if logged in (if not, make sure to reroute to index to avoid error messages)
before do
    
    userresult = userresult()

    restricted_paths = ['/monsters', '/market', '/toys', '/foods']

    for i in 0..restricted_paths.length-1

        restricted_paths[i] = Regexp.new(restricted_paths[i])
        match = /#{restricted_paths[i]}/.match(request.path_info)

        if match && session[:log_in] != true || /\/users\/\d/.match(request.path_info) && session[:log_in] != true
            redirect('/')
        end
    end
end

get('/') do

    if session[:log_in]
        slim(:"index", locals:{users:userresult})
    else
        slim(:"index")
    end
end

# Users

#could users be restful:d??
get('/users/') do
    if session[:log_in]
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

    if userresult['Admin'] == "Admin"
        result = all_users()
        slim(:"users/show", locals:{users:userresult, userlist:result})
    else
        slim(:"users/show", locals:{users:userresult})
    end
end

post('/log_in') do
    username = params[:username]
    password = params[:password]

    check_login = check_login(username, password)
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

    if session[:error_reg_password] || session[:error_reg_unik]
    redirect('/users/new')
    else
        redirect('/')
    end
end

get('/users/:id/edit') do
    id = params[:id].to_i

    if userresult['Id'] != id
        userresult = user(id)
    end

    slim(:"users/edit", locals:{users:userresult})
end

post('/password_check/:id') do
    session[:password_checked_error] = false
    session[:password_checked] = false

    id = params[:id]
    password = params[:password]
    username = params[:username]

    if userresult['Admin']
        if username == userresult['Username']

            check = checkpassword(password, username)

            if check
                session[:password_checked] = true
            else
                session[:password_checked_error] = true
            end
        else
            session[:password_checked_error] = true
        end

    else
        user = user(id)

        if username == user['Username']
        
            check = checkpassword(password, username)

            # could this in theory be moved into the function?
            if check
                session[:password_checked] = true
            else
                session[:password_checked_error] = true
            end
        else
            session[:password_checked_error] = true
        end
    end

    redirect("/users/#{id}/edit")

end

post('/users/:id/update') do
    id = params[:id]

    username = params[:username]
    password = params[:password]

        if username != ""
            username_update(username, id)
        end
        if password != ""
            password_update(password, id)
        end
    
    redirect('/')
end

post('/users/:id/delete') do
    id = params[:id]
    delete_user(id)
    redirect('/')
end

# Monsters

get('/monsters/') do
    id = session[:id]

    if userresult['Admin'] == "Admin"
        result = all_monsters()
    else
        result = user_monsters(id)
    end
    slim(:"monsters/index", locals:{monsters:result, users:userresult})
end

get('/monsters/new') do
    result = $db.execute("SELECT * FROM types")
    # I believe this could be done with helpers

    slim(:"monsters/new", locals:{users:userresult, types:result})
end

get('/monsters/:id') do
    id = params[:id].to_i
    
    result = monster(id)
    typeresult = monsters_types(id)

    slim(:"monsters/show", locals:{monsters:result, types:typeresult, users:userresult})
end

get('/monsters/:id/edit') do
    id = params[:id].to_i
    
    result = monster(id)
    typeresult = monsters_types(id)
    alltypes = $db.execute("SELECT * FROM types")
    # could probably be handled with a helper function

    slim(:"monsters/edit", locals:{monsters:result, users:userresult, types:typeresult, alltypes:alltypes})
end

post('/monsters') do
    @name = params[:name]
    @age = params[:age]
    @desc = params[:desc]
    @type1 = params[:type1]
    @type2 = params[:type2]
    @userid = session[:id]
    @fed = "False"
    @sold = 1
    session[:type_match] = false

    if @type1 == @type2
        session[:type_match] = true
        redirect('/monsters/new')
    end

    new_monster()

    redirect('/monsters/')
end

post('/monsters/:id/update') do
    session[:type_match] = false
    session[:ownership_false_monster] = false
    
    # check user owns pets
    # check if user is admin

    @id = params[:id]
    @name = params[:name]
    @age = params[:age]
    @desc = params[:desc]
    @userid = params[:userid]
    @type1 = params[:type1]
    @type2 = params[:type2]
    @previous_types = previous_types_monster(@id)
    monster = monster(@id)

    if @type1 == @type2 && @type1 != nil
        session[:type_match] = true
        redirect("/monsters/#{@id}/edit")
    elsif userresult['Admin'] == "Admin" || monster['UserId'] == userresult['Id']
        update_monster()
    else
        session[:ownership_false_monster] = true
        redirect("/monsters/#{@id}/edit")
    end

    redirect("/monsters/")
end

post('/monsters/:id/sell') do 
    id = params[:id]
    @sold_item = "monster"
    sell(id)

    if session[:ownership_false_monster]
        redirect('/monsters/#{id}/edit')
    end

    redirect('/monsters/')
end

post('/monsters/:id/delete') do
    session[:ownership_false_monster] = false
    id = params[:id]
  
    if userresult['Admin'] == "Admin"
        delete_monster(id)
    else
        session[:ownership_false_monster] = true
        redirect("/monsters/#{@id}/edit")
    end
    redirect("/monsters/")
end

# Foods

get('/foods/') do
    session[:type_match] = false
    
    id = userresult['Id']

    if userresult['Admin'] == "Admin"
        result = all_foods(id)
    else
        result = user_foods(id)
        for i in 0..result.length-1 do
            if result[i]['FoodAmount'] == 0
                remove_user_food(result[i]['Id'], result[i]['UserId'])
            end
        end
    end

    slim(:"foods/index", locals:{foods:result, users:userresult})
end

get('/foods/new') do
    alltypes = $db.execute("SELECT * FROM types")
    # Should be possible to use helper functions

    slim(:"foods/new", locals:{users:userresult, alltypes:alltypes})
end

get('/foods/:id') do
    id = params[:id].to_i
    
    result = food(id)
    typeresult = food_types(id)

    slim(:"foods/show", locals:{foods:result, users:userresult, types:typeresult})
end

get('/foods/:id/edit') do
    id = params[:id].to_i
    
    result = food(id)
    typeresult = food_types(id)
    alltypes = $db.execute("SELECT * FROM types")
    # HELPER

    slim(:"foods/edit", locals:{foods:result, users:userresult, types:typeresult, alltypes:alltypes})
end

post('/foods') do
    session[:type_match] = false

    @name = params[:name]
    @desc = params[:desc]
    @type1 = params[:type1]
    @type2 = params[:type2]
    @type3 = params[:type3]
    @amount = params[:amount] 
    p "amountcheck"
    p @amount

    if @type1 != @type2 && @type1 != @type3 && @type2 != @type3 && userresult['Admin'] == "Admin" 
        new_food()
    else
        session[:type_match] = true
        redirect('/foods/new')
    end

    redirect('/foods/')
end

post('/foods/:id/update') do
    session[:type_match] = false

    @id = params[:id]
    @name = params[:name]
    @desc = params[:desc]
    @type1 = params[:type1]
    @type2 = params[:type2]
    @type3 = params[:type3]
    @previous_types = previous_types_food(@id)
    @amount = params[:amount]
    p "amountcheck"
    p @amount

    if @type1 == @type2 || @type1 == @type3 || @type2 == @type3
        session[:type_match] = true
        redirect("/foods/#{id}/edit")
    elsif userresult['Admin'] == "Admin"
        update_food()
    else 
        redirect("/foods/#{@id}/edit")
    end

    redirect('/foods/')
end

post('/foods/:id/delete') do
    id = params[:id]
  
    if userresult['Admin'] == "Admin"
        delete_food(id)
    else
        redirect("/foods/#{@id}/edit")
    end
    redirect("/foods/")
end

# Toys

get('/toys/') do
    id = userresult['Id']
    
    if userresult['Admin'] == "Admin"
        result = all_toys()
    else
        result = user_toys(id)
    end
    slim(:"toys/index", locals:{toys:result, users:userresult})
end

get('/toys/new') do
    alltypes = $db.execute("SELECT * FROM types")

    slim(:"toys/new", locals:{users:userresult, alltypes:alltypes})
end

get('/toys/:id') do
    id = params[:id].to_i

    result = toy(id)
    slim(:"toys/show", locals:{toys:result, users:userresult})
end

get('/toys/:id/edit') do
    id = params[:id].to_i
    
    result = toy(id)
    alltypes = $db.execute("SELECT * FROM types")

    slim(:"toys/edit", locals:{toys:result, users:userresult, alltypes:alltypes})
end

post('/toys') do
    @name = params[:name]
    @desc = params[:desc]
    @type = params[:type]
    @sold = 1

    if userresult['Admin'] == "Admin"
        new_toy()
    end

    redirect('/toys/')
end

post('/toys/:id/update') do
    @id = params[:id]
    @name = params[:name]
    @desc = params[:desc]
    @type = params[:type]

    if userresult['Admin'] != "Admin"
        redirect('/toys/#{@id}/edit')
    else
        update_toy()
    end
    redirect('/toys/')
end

post('/toys/:id/sell') do 
    id = params[:id]
    @sold_item = "toy"
    sell(id)

    if session[:ownership_false_toy]
        redirect('/toys/#{id}/edit')
    end

    redirect('/toys/')
end

post('/toys/:id/delete') do
    id = params[:id]
  
    if userresult['Admin'] == "Admin"
        delete_toy(id)
    else
        redirect("/toys/#{@id}/edit")
    end
    redirect("/toys/")
end

# market

get('/market/') do
    
    monstersresult = sold_pets() 
    foodsresult = sold_foods()
    toysresult = sold_toys()

    slim(:"market/index", locals:{users:userresult, monsters:monstersresult, foods:foodsresult, toys:toysresult})
end

get("/market/toys/:id") do
    id = params[:id]
    session[:market] = "toy"

    result = toy(id)
    slim(:"market/show", locals:{users:userresult, toys:result})
end

post("/market/toys/:id/update") do
    id = params[:id]
    @purchased_item = "toy"

    purchase(id)

    redirect("/toys/")
end

get("/market/foods/:id") do
    id = params[:id]
    session[:market] = "food"

    result = market_food(id)
    typeresult = food_types(id)

    slim(:"market/show", locals:{users:userresult, foods:result, types:typeresult})
end

post("/market/foods/:id/update") do
    id = params[:id]
    @purchased_item = "food"

    @amount = params[:amount].to_i
    p "FOOD TEST"
    p @amount

    purchase(id)

    redirect("/foods/")
end

get("/market/monsters/:id") do
    id = params[:id]
    session[:market] = "monster"

    result = monster(id)
    typeresult = monsters_types(id)

    slim(:"market/show", locals:{users:userresult, monsters:result, types:typeresult})
end

post("/market/monsters/:id/update") do
    id = params[:id]
    @purchased_item = "monster"

    purchase(id)

    redirect("/monsters/")

end