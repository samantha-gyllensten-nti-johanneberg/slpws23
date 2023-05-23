#relevant functions
require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'
enable :sessions

def userresult()
    id = session[:id]
    userresult = $db.execute("SELECT * FROM users WHERE Id = ?", id).first

    return userresult
end

def check_login(username, password)

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

    if checkpassword == false #If the username does not exist (added to niot break code), or the password does not match
        # Username or password is wrong, error
        session[:error_log_in] = true
        login_log(username)
        redirect('/users/')
    else
        # Sees if login is timed out
        timeout_check(username)

        # Logs user in
        session[:log_in] = true

        id = find_user_id(username)

        redirect('/')
    end

end

def timeout_check(username)
    session[:too_may_attempts] = false
    timeout_date = $db.execute("SELECT TimeoutLogin FROM users WHERE Username = ?", username).first
    timeout_date = timeout_date['TimeoutLogin'].to_f

    if timeout_date
        time_now = Time.new.to_f
        if time_now > timeout_date
            return
        else
            session[:too_may_attempts] = true
            redirect('/users/')
        end
        return
    end  
end

def login_log(username)

    time = Time.new.to_f

    if $db.execute("SELECT * FROM login_log WHERE Username = ?", username).first

        time2 = $db.execute("SELECT Time1 FROM login_log WHERE Username = ?", username).first
        time3 = $db.execute("SELECT Time2 FROM login_log WHERE Username = ?", username).first
        $db.execute("Update login_log SET Time1 = ?, Time2 = ?, Time3 = ? WHERE Username = ?", time, time2['Time1'], time3['Time2'], username)

        if $db.execute("SELECT Time1, Time2, Time3 FROM login_log WHERE Username = ?", username).first

            time2 = time2['Time1'].to_f
            time3 = time3['Time2'].to_f
        
            if time - time2 < 5.0 && time2 - time3 < 5.0

                if $db.execute("SELECT * FROM users WHERE Username = ?", username).first

                    timeout = Time.new + (60 * 3)
                    timeout = timeout.to_f
                    
                    $db.execute("UPDATE users SET TimeoutLogin = ? WHERE Username = ?", timeout, username)

                end
            end
        end 

    else
        $db.execute("INSERT INTO login_log (Username, Time1) VALUES (?, ?)", username, time)
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

def all_users()
    return $db.execute("SELECT Id, Username, Admin FROM users")
end

def user(id)
    return $db.execute("SELECT * FROM users WHERE Id = ?", id).first
end

def username_update(username, id)
    $db.execute("UPDATE users SET Username = ? WHERE Id = ?", username, id)
end

def password_update(password, id)
    password = BCrypt::Password.create(password)
    $db.execute("UPDATE users SET Password = ? WHERE Id = ?", password, id)
end

def delete_user(id)
    $db.execute("DELETE FROM users WHERE id = ?", id)
end

def all_monsters()
    return $db.execute("SELECT * FROM monsters")
end

def user_monsters(id)
    $db.execute("SELECT * FROM monsters WHERE UserId = ?", id)
end

def monster(id)
    return $db.execute("SELECT * FROM monsters WHERE Id = ?", id).first
end

def monsters_types(id)
    return $db.execute("SELECT monsters_types_rel.TypeId, types.Type FROM monsters_types_rel INNER JOIN monsters ON monsters_types_rel.MonsterId = monsters.Id INNER JOIN types ON monsters_types_rel.TypeId = types.Id WHERE monsters.Id = ?", id)
end

def new_monster()
    $db.execute("INSERT INTO monsters (Name, Age, Fed, UserId, Description, SoldStatus) VALUES (?, ?, ?, ?, ?, ?)", @name, @age, @fed, @userid, @desc, @sold)
    id = $db.execute("SELECT last_insert_rowid()")
    id = id[0]["last_insert_rowid()"]
    $db.execute("INSERT INTO monsters_types_rel (TypeId, MonsterId) VALUES (?, ?)", @type1, id)
    $db.execute("INSERT INTO monsters_types_rel (TypeId, MonsterId) VALUES (?, ?)", @type2, id)
end

def previous_types_monster(id)
    return $db.execute("SELECT TypeId FROM monsters_types_rel WHERE MonsterId = ?", id)
end

def update_monster()
    if @name != "" && @name != nil
        $db.execute("UPDATE monsters SET Name = ? WHERE Id = ?", @name, @id)
    end
    if @age != "" && @age != nil 
        $db.execute("UPDATE monsters SET Age = ? WHERE Id = ?", @age, @id)
    end
    if @desc != "" && @desc != nil
        $db.execute("UPDATE monsters SET Description = ? WHERE Id = ?", @desc, @id)
    end
    if @userid != "" && @userid != nil
        $db.execute("UPDATE monsters SET UserId = ? WHERE Id = ?", @userid, @id)
    end
    if @type1 != "" && @type1 != nil
        $db.execute("UPDATE monsters_types_rel SET TypeId = ? WHERE MonsterId = ? AND TypeId = ?", @type1, @id, @previous_types[0]['TypeId'])
    end
    if @type2 != "" && @type2 != nil
        $db.execute("UPDATE monsters_types_rel SET TypeId = ? WHERE MonsterId = ? AND TypeId = ?", @type2, @id, @previous_types[1]['TypeId'])
    end
end

def delete_monster(id)
    $db.execute("DELETE FROM monsters WHERE id = ?", id)
end

def all_foods(id)
    return $db.execute("SELECT * FROM foods")
end

def user_foods(id)
    return $db.execute("SELECT * FROM users_foods_rel INNER JOIN foods ON foods.Id = users_foods_rel.FoodId WHERE UserId = ?", id)
end

def food(id)
    if userresult['Admin'] == "Admin"
        return $db.execute("SELECT foods.Id, foods.name, foods.Description, market_foods.MarketAmount FROM foods INNER JOIN market_foods ON market_foods.FoodId = foods.Id WHERE foods.Id = ?", id).first
    else
        return $db.execute("SELECT foods.Id, foods.name, foods.Description, users_foods_rel.FoodAmount FROM foods INNER JOIN market_foods ON market_foods.FoodId = foods.Id INNER JOIN users_foods_rel ON users_foods_rel.FoodId = foods.Id WHERE foods.Id = ? AND UserId = ?", id, userresult['Id']).first
    end
end

def food_types(id)
    return $db.execute("SELECT foods_types_rel.TypeId, types.Type FROM foods_types_rel INNER JOIN foods ON foods_types_rel.FoodId = foods.Id INNER JOIN types ON foods_types_rel.TypeId = types.Id WHERE foods.Id = ?", id)
end

def new_food()
    $db.execute("INSERT INTO foods (Name, Description) VALUES (?, ?)", @name, @desc)

    id = $db.execute("SELECT last_insert_rowid()")
    id = id[0]["last_insert_rowid()"]

    $db.execute("INSERT INTO foods_types_rel (TypeId, FoodId) VALUES (?, ?)", @type1, id)
    $db.execute("INSERT INTO foods_types_rel (TypeId, FoodId) VALUES (?, ?)", @type2, id)
    $db.execute("INSERT INTO foods_types_rel (TypeId, FoodId) VALUES (?, ?)", @type3, id)
    $db.execute("Insert INTO market_foods (FoodId, MarketAmount) VALUES (?, ?)", id, @amount)
end

def previous_types_food(id)
    return $db.execute("SELECT TypeId FROM foods_types_rel WHERE FoodId = ?", id)
end

def update_food()
    if @name != ""
        $db.execute("UPDATE foods SET Name = ? WHERE Id = ?", @name, @id)
    end
    if @name != ""
        $db.execute("UPDATE foods SET Description = ? WHERE Id = ?", @desc, @id)
    end
    if @type1 != ""
        $db.execute("UPDATE foods_types_rel SET TypeId = ? WHERE FoodId = ? AND TypeId = ?", @type1, @id, @previous_types[0]['TypeId'])
    end
    if @type2 != ""
        $db.execute("UPDATE foods_types_rel SET TypeId = ? WHERE FoodId = ? AND TypeId = ?", @type2, @id, @previous_types[1]['TypeId'])
    end
    if @type3 != ""
        $db.execute("UPDATE foods_types_rel SET TypeId = ? WHERE FoodId = ? AND TypeId = ?", @type3, @id, @previous_types[2]['TypeId'])
    end
    if @amount != ""
        $db.execute("UPDATE market_foods SET MarketAmount = ? WHERE FoodId = ?", @amount, @id)
    end
end

def delete_food(id)
    $db.execute("DELETE FROM foods WHERE id = ?", id)
end

def all_toys()
    return $db.execute("SELECT * FROM toys")
end

def user_toys(id)
    return $db.execute("SELECT * FROM toys WHERE UserId = ?", id)
end

def toy(id)
    return $db.execute("SELECT toys.Id, toys.Name, toys.Description, toys.TypeId, toys.UserId, types.Type FROM toys INNER JOIN types ON types.Id = toys.TypeId WHERE toys.Id = ?", id).first
end

def new_toy()
    $db.execute("INSERT INTO toys (Name, Description, TypeId, Solstatus) VALUES (?, ?, ?, ?)", @name, @desc, @type, @sold)
end

def update_toy
    if @name != ""
        $db.execute("UPDATE toys SET Name = ? WHERE Id = ?", @name, @id)
    end
    if @desc != ""
        $db.execute("UPDATE toys SET Descrpition = ? WHERE Id = ?", @desc, @id)
    end
    if @type != ""
        $db.execute("UPDATE toys SET TypeId = ? WHERE Id = ?", @type, @id)
    end
end

def delete_toy(id)
    $db.execute("DELETE FROM toy WHERE id = ?", id)
end

def sold_pets()
    $db.execute("SELECT * FROM monsters WHERE SoldStatus = 1")
end

def sold_toys()
    $db.execute("SELECT * FROM toys WHERE SoldStatus = 1")
end

def sold_foods()
    $db.execute("SELECT foods.Id, foods.name, foods.Description, market_foods.MarketAmount FROM foods INNER JOIN market_foods ON foods.Id = market_foods.FoodId")
end

def remove_user_food(id, userid)
    $db.execute("DELETE FROM users_foods_rel WHERE FoodId = ? AND UserId = ?", id, userid)
end

def market_food(id)
    return $db.execute("SELECT foods.Id, foods.name, foods.Description, market_foods.MarketAmount FROM foods INNER JOIN market_foods ON market_foods.FoodId = foods.Id WHERE foods.Id = ?", id).first
end

def purchase(id)
    userid = userresult['Id']

    if userresult['Admin'] != "Admin"
        if @purchased_item == "monster"
            $db.execute("UPDATE monsters SET UserId = ?, SoldStatus = 0 WHERE Id = ?", userid, id)
        elsif @purchased_item == "toy"
            $db.execute("UPDATE toys SET UserId = ?, SoldStatus = 0 WHERE Id = ?", userid, id)
        else
            if $db.execute("SELECT * FROM users_foods_rel WHERE FoodId = ? AND UserId = ?", id, userid)
                $db.execute("UPDATE users_foods_rel SET FoodAmount = ? WHERE UserId = ? AND FoodId = ?", @amount, userid, id)
            else
                $db.execute("INSERT into users_foods_rel (FoodId, UserId, FoodAmount) Values (?, ?, ?)", id, userid, @amount)
            end
            old_amount = $db.execute("SELECT MarketAmount FROM market_foods WHERE FoodId = ?", id).first
            new_amount = old_amount['MarketAmount'] - @amount
            $db.execute("Update market_foods SET MarketAmount = ? WHERE FoodId = ?", new_amount, id)
        end
    end
end

def sell(id)
    userid = userresult['Id']

    if @sold_item == "toy"
        if $db.execute("SELECT * FROM toys where Id = ? AND UserId = ?", id, userid).first
            $db.execute("UPDATE toys SET UserId = 1, SoldStatus = 1 WHERE Id = ?", id)
        else
            session[:ownership_false_toy] = true
        end
    else
        if $db.execute("SELECT * FROM monsters where Id = ? AND UserId = ?", id, userid).first
            $db.execute("UPDATE monsters SET UserId = 1, SoldStatus = 1 WHERE Id = ?", id)
        else
            session[:ownership_false_monster] = true
        end
    end
end