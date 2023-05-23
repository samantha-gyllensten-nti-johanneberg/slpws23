#main controller
require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'
# require 'yard'
# require 'yard-sinatra'
require './model.rb'

enable :sessions

include Model

# Declares a global variable for database access
$db = connect_to_db_hash()
# Executes SQL code required for CASCADE SQL functions
$db.execute("PRAGMA foreign_keys = ON")


helpers do
    def userresult()
        id = session[:id]
        userresult = $db.execute("SELECT * FROM users WHERE Id = ?", id).first
        
        return userresult
    end

    def types()
        result = $db.execute("SELECT * FROM types")
        return result
    end
end

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

# Displays landing page
get('/') do
    slim(:"index")
end

# Displays a login or logout form depending on login status
get('/users/') do
    slim(:"users/index")
end

# Displays a registration form
get('/users/new') do
    slim(:"users/new")
end

# Displays users information, or if the user is an admin, all users information
#
# @see Model#all_users
get('/users/:id') do

    if userresult['Admin'] == "Admin"
        result = all_users()
        slim(:"users/show", locals:{userlist:result})
    else
        slim(:"users/show")
    end
end

# Attempts to log the user in using the login form
# 
# @param username [String], the username
# @param password [String] the password entered
# 
# @see Model#check_login
post('/log_in') do
    username = params[:username]
    password = params[:password]

    check_login = check_login(username, password)
end

# Logs user out and destroys session
post('/log_out') do
    session.destroy
    redirect('/')
end

# Attempts to register users using the registration form
# 
# @param [String] username, the username
# @param [String] password, the password
# @param [String] confirm_password, the password confirmation
# 
# @see Model#check_register
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

# Displays an edit form for the user with the :id
# 
# @param [Integer] :id, the ID of the user being edited (note, not necessarily active user)  
# 
# @see Model#user
get('/users/:id/edit') do
    id = params[:id].to_i

    if userresult['Id'] != id
        userresult = user(id)
    end

    slim(:"users/edit")
end

# Checks if password and username are either that of the user being edited, or an Admin
# 
# @param [String] password, the password
# @param [String] username, the username
# @param [Integer] :id, the Id of the edited user
# 
# @see Model#checkpassword
# @see Model#user
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

# Updates users information in database
# 
# @param [String] username, the username
# @param [String] password, the password
# @param [Integer] :id, the Id of the edited user
# 
# @see Model#username_update
# @see Model#password_update
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

# Deletes user from database
# 
# @param [Integer] :id, the Id of the deleted user
# 
# @see Model#delete_user
post('/users/:id/delete') do
    id = params[:id]
    delete_user(id)
    redirect('/')
end


# Displays users monsters, or all monsters if the user is an Admin
# 
# @param [Integer] :id, the logged in users' Id
# 
# @see Model#all_monsters
# @see Model#user_monsters
get('/monsters/') do
    id = session[:id]

    if userresult['Admin'] == "Admin"
        result = all_monsters()
    else
        result = user_monsters(id)
    end
    slim(:"monsters/index", locals:{monsters:result})
end

# Displays a form to create a new monster
get('/monsters/new') do
    slim(:"monsters/new")
end

# Displays a monsters information
# 
# @param [Integer] :id, the monster's Id
# 
# @see Model#monster
# @see Model#monster_types
get('/monsters/:id') do
    id = params[:id].to_i
    
    result = monster(id)
    typeresult = monsters_types(id)

    slim(:"monsters/show", locals:{monsters:result, monstertypes:typeresult})
end

# Displays a form to edit a monsters information
# 
# @param [Integer] :id, the monster's Id
# 
# @see Model#monster
# @see Model#monster_types
get('/monsters/:id/edit') do
    id = params[:id].to_i
    
    result = monster(id)
    typeresult = monsters_types(id)

    slim(:"monsters/edit", locals:{monsters:result, users:userresult, monstertypes:typeresult})
end

# Attempts to insert an entry into the monsters table in the database
# 
# @param [String] name, the name of the monster
# @param [Integer] age, the age of the monster
# @param [String] desc, the description of the monster
# @param [Integer] type1, the first type for the monster using the Type's Id
# @param [Integer] type2, the second type for the monster using the Type's Id
# @param [Integer] userid, the Id of the user and owner the monster
# @param [String] fed, the fed status of the monster - automatically fed upon creation
# @param [Integer] sold, the status of if the monster is being sold - in binary 1 is being sold and the monster is automatically sold upon creation
# 
# @see Model#new_monster
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

# Attempts to update an entry into the monsters table in the database
# 
# @param [Integer] :id, the monster's Id
# @param [String] name, the name of the monster
# @param [Integer] age, the age of the monster
# @param [String] desc, the description of the monster
# @param [Integer] type1, the first type for the monster using the Type's Id
# @param [Integer] type2, the second type for the monster using the Type's Id
# @param [Array] previous_types, an array containing the previous types of the monster
# 
# @see Model#previous_types_monster
# @see Model#update_monster
post('/monsters/:id/update') do
    session[:type_match] = false
    session[:ownership_false_monster] = false
    
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

# Attempts to update a monster's entry to display as being sold on the market. Temporarily moved to Admin user
# 
# @param [Integer] :id. the monster's Id
# @param [String] sold_item, declares that the sold item is a monster
# 
# @see Model#sell
post('/monsters/:id/sell') do 
    id = params[:id]
    @sold_item = "monster"
    sell(id)

    if session[:ownership_false_monster]
        redirect('/monsters/#{id}/edit')
    end

    redirect('/monsters/')
end

# Attempts to delete an entry from the monster table
# 
# @param [Integer] :id. the monster's Id
# 
# @see Model#delete_monster
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


# Displays a users foods, or if the user is an Admin, all foods
# 
# @param [Integer] :id, the user's id
# 
# @see Model#all_foods
# @see Model#user_foods
# @see Model#remove_user_food
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

    slim(:"foods/index", locals:{foods:result})
end

# Displays a form to create a new food
get('/foods/new') do
    slim(:"foods/new")
end

# Displays the information for the correlating food to id
# 
# @param [Integer] :id, the food's Id
# 
# @see Model#food
# @see Model#food_types
get('/foods/:id') do
    id = params[:id].to_i
    
    result = food(id)
    typeresult = food_types(id)

    slim(:"foods/show", locals:{foods:result, foodtypes:typeresult})
end

# Displays a form to edit a food's entry
# 
# @param [Integer] :id, the food's Id
# 
# @see Model#food
# @see Model#food_types
get('/foods/:id/edit') do
    id = params[:id].to_i
    
    result = food(id)
    typeresult = food_types(id)

    slim(:"foods/edit", locals:{foods:result, foodtypes:typeresult})
end

# Attempts to create a new entry for food in the foods table
# 
# @param [String] name, the food's name
# @param [String] desc, the food's description
# @param [Integer] type1, the first type capable of consuming the food
# @param [Integer] type2, the second type capable of consuming the food
# @param [Integer] type3, the third type capable of consuming the food
# @param [Integer] amount, the amount of food available in total
# 
# @see Model#new_food
post('/foods') do
    session[:type_match] = false

    @name = params[:name]
    @desc = params[:desc]
    @type1 = params[:type1]
    @type2 = params[:type2]
    @type3 = params[:type3]
    @amount = params[:amount]

    if @type1 != @type2 && @type1 != @type3 && @type2 != @type3 && userresult['Admin'] == "Admin" 
        new_food()
    else
        session[:type_match] = true
        redirect('/foods/new')
    end

    redirect('/foods/')
end

# Attempts to update an existing entry in the food table
# 
# @param [String] name, the food's name
# @param [String] desc, the food's description
# @param [Integer] type1, the first type capable of consuming the food
# @param [Integer] type2, the second type capable of consuming the food
# @param [Integer] type3, the third type capable of consuming the food
# @param [Integer] amount, the amount of food available in total
# @param [Array] previous_types, an array containing the previous types of the food
# @param [Integer] amount, the amount of food available in total 
# 
# @see Model#update_food
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

# Attempts to delete an entry from the food table
# 
# @param [Integer] :id, the food's Id
# 
# @see Model#delete_food
post('/foods/:id/delete') do
    id = params[:id]
  
    if userresult['Admin'] == "Admin"
        delete_food(id)
    else
        redirect("/foods/#{@id}/edit")
    end
    redirect("/foods/")
end





# Displays the users toys, or all toys if the user is an admin
# 
# @param [Integer] :id, the user's Id
# 
# @see Model#all_toys
# @see Model#user_toys
get('/toys/') do
    id = userresult['Id']
    
    if userresult['Admin'] == "Admin"
        result = all_toys()
    else
        result = user_toys(id)
    end
    slim(:"toys/index", locals:{toys:result})
end

# Displays a form to create a new entry for the toys table
get('/toys/new') do
    slim(:"toys/new")
end

# Displays the information of a toy
# 
# @param [Integer] :id, the toy's Id
# 
# @see Model#toy
get('/toys/:id') do
    id = params[:id].to_i

    result = toy(id)
    slim(:"toys/show", locals:{toys:result})
end

# Displays a form to edit an entry in the toy table
# 
# @param [Integer] :id, the toy's Id
# 
# @see Model#toy
get('/toys/:id/edit') do
    id = params[:id].to_i
    
    result = toy(id)

    slim(:"toys/edit", locals:{toys:result})
end

# Attempts to create a new entry in the toy table
# 
# @param [String] name, the toy's name
# @param [String] desc, the toy's description
# @param [Integer] type, the toy's type Id
# @param [Integer] sold, the toy's sold status which defaults to 1 which corresponds to being sold and is displayed in binary
# 
# @see Model#new_toy
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

# Attempts to update an entry in the toy table
# 
# @param [Integer] :id, the toy's Id
# @param [String] name, the toy's name
# @param [String] desc, the toy's description
# @param [Integer] type, the toy's type Id
# 
# @see Model#update_toy
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

# Attempts to update a toy's entry to display as being sold on the market. Temporarily moved to Admin user
# 
# @param [Integer] :id, the toy's Id
# 
# @see Model#sell
post('/toys/:id/sell') do 
    id = params[:id]
    @sold_item = "toy"
    sell(id)

    if session[:ownership_false_toy]
        redirect('/toys/#{id}/edit')
    end

    redirect('/toys/')
end

# Attempts to delete an entry from the toys table
# 
# @param [Integer] :id, the toy's Id
# 
# @see Model#delete_toy
post('/toys/:id/delete') do
    id = params[:id]
  
    if userresult['Admin'] == "Admin"
        delete_toy(id)
    else
        redirect("/toys/#{@id}/edit")
    end
    redirect("/toys/")
end



# Displays sold monsters, foods, and toys
get('/market/') do
    
    monstersresult = sold_pets() 
    foodsresult = sold_foods()
    toysresult = sold_toys()

    slim(:"market/index", locals:{monsters:monstersresult, foods:foodsresult, toys:toysresult})
end

# Displays the information of a toy entry that is being sold
# 
# @param [Integer] :id, the toy's Id
# 
# @see Model#toy
get("/market/toys/:id") do
    id = params[:id]
    session[:market] = "toy"

    result = toy(id)
    slim(:"market/show", locals:{toys:result})
end

# Attempts to update the toy's sold status and register a new user/owner
# 
# @param [Integer] :id, the toy's Id
# @param [String] purchased_item, the type of object being purchased/updated
# 
# @see Model#purchase
post("/market/toys/:id/update") do
    id = params[:id]
    @purchased_item = "toy"

    purchase(id)

    redirect("/toys/")
end

# Displays the information of a food entry that is being sold
# 
# @param [Integer] :id, the food's Id
# 
# @see Model#market_food
# @see Model#food_types
get("/market/foods/:id") do
    id = params[:id]
    session[:market] = "food"

    result = market_food(id)
    typeresult = food_types(id)

    slim(:"market/show", locals:{foods:result, foodtypes:typeresult})
end

# Attempts to update the food's sold status and register a new user/owner
# 
# @param [Integer] :id, the food's Id
# @param [String] purchased_item, the type of object being purchased/updated
# @param [Integer] amount, the amount of the object being purchased
# 
# @see Model#purchase
post("/market/foods/:id/update") do
    id = params[:id]
    @purchased_item = "food"
    @amount = params[:amount].to_i

    purchase(id)

    redirect("/foods/")
end

# Displays the information of a monster's entry that is being sold
# 
# @param [Integer] :id, the monster's Id
# 
# @see Model#monster
# @see Model#monsters_types
get("/market/monsters/:id") do
    id = params[:id]
    session[:market] = "monster"

    result = monster(id)
    typeresult = monsters_types(id)

    slim(:"market/show", locals:{monsters:result, monstertypes:typeresult})
end

# Attempts to update the monster's sold status and register a new user/owner
# 
# @param [Integer] :id, the monster's Id
# @param [String] purchased_item, the type of object being purchased/updated
# 
# @see Model#purchase
post("/market/monsters/:id/update") do
    id = params[:id]
    @purchased_item = "monster"

    purchase(id)

    redirect("/monsters/")

end