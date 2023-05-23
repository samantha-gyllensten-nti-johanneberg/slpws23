#relevant functions
require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'
# require 'yard'
# require 'yard-sinatra'
enable :sessions

module Model

    # Compares the username and password against those registered in the database
    # 
    # @param username [String] the username
    # @param password [String] the password entered
    # 
    # @see Model#checkusername
    # @see Model#checkpassword
    # @see Model#login_log
    # @see Model#timeout_check
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
            find_user_id(username)

            redirect('/')
        end
    end

    # Looks if the username has a timeout limit, and if it does, if it has been long enough since past login attempts
    # 
    # @param username [String] the username
    # 
    # @return [boolean]
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

    # Logs the time of an attempted login, as well as compares the time between login attempts to apply a timeout if necessary
    # 
    # @param username [String] the username
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

    # Connects to database as a hash
    def connect_to_db_hash()
        db = SQLite3::Database.new("db/multipets.db")
        db.results_as_hash = true
        return db
    end

    # Checks if the username is registered in the database
    # 
    # @params [String] username, the username
    # 
    # @return [Hash]
    #   *:Id [Integer] the Id of the user
    #   *:Username [String] the username of the user
    #   *:Password [String] the password of the user
    #   *:Admin [String] the admin status of the user
    #   *:TimeoutLogin [String] the timeout status for login attempts
    def checkusername(username)
        username = username
        checkuser = $db.execute("SELECT * FROM users WHERE Username = ?", username)

        return checkuser
    end

    # Checks if the password matches the one registered to the username in the database
    # 
    # @params [String] username, the username
    # @param password [String] the password
    # 
    # @return [boolean]
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

    # Checks if the username is not already registered and the two entered passwords match to be inserted into the database
    # 
    # @params [String] username the username
    # @param password [String] the password
    # @param [String] confirm_password the repeated password for validation purposes
    # 
    # @see Model#checkusername
    # @see Model#register_user
    # @see Model#find_user_id
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

    # Inserts the user into the database
    # 
    # @params [String] username the username
    # @param password [String] the password
    def register_user(username, password)
        $db.execute("INSERT INTO users (Username, Password) VALUES (?, ?)", username, password)
    end

    # Finds the Id of the user and assigns a session to its value
    # 
    # @params [String] username the username
    def find_user_id(username)
        #Checks the id of the user and assigns it to the session
        id = $db.execute("SELECT Id FROM users WHERE Username LIKE ?", username).first
        session[:id] = id['Id']
    end

    # Selects the Id, Username and Admin status from users
    # 
    # @return [Hash]
    #   *:Id [Integer] the Id of each user
    #   *:Username [String] the username of each user
    #   *:Admin [String] the Admin status of each user
    def all_users()
        return $db.execute("SELECT Id, Username, Admin FROM users")
    end

    # Selects all information from a users entry in the users table
    # 
    # @params id [Integer] the Id of each user
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of each user
    #   * :Username [String] the username of each user
    #   * :password [String] the password
    #   * :Admin [String] the Admin status of each user
    #   *:TimeoutLogin [String] the timeout status for login attempts
    def user(id)
        return $db.execute("SELECT * FROM users WHERE Id = ?", id).first
    end

    # Attempts to update a username inside the database with the corresponding Id
    # 
    # @params [String] username the username
    # @params id [Integer] the Id of each user
    def username_update(username, id)
        $db.execute("UPDATE users SET Username = ? WHERE Id = ?", username, id)
    end

    # Attempts to update a password inside the database with the corresponding Id
    # 
    # @param password [String] the password
    # @params id [Integer] the Id of each user
    def password_update(password, id)
        password = BCrypt::Password.create(password)
        $db.execute("UPDATE users SET Password = ? WHERE Id = ?", password, id)
    end

    # Attempts to delete a user with the corresponding Id
    # 
    # @params id [Integer] the Id of each user
    def delete_user(id)
        $db.execute("DELETE FROM users WHERE id = ?", id)
    end

    # Selects the information of all entries in the monsters table
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of the monster
    #   * :Name [String] the name of the monster
    #   * :Age [Integer] the age of the monster
    #   * :Fed [String] the fed status of the monster
    #   * :UserId [Integer] the Id of the owner user
    #   * :ImageLink [String] the link to the monster's image
    #   * :Description [String] the description of the monster
    #   * :SoldStatus [Integer] the sold status of the monster
    def all_monsters()
        return $db.execute("SELECT * FROM monsters")
    end

    # Selects all the information of the entries in the monsters table where the userid corresponds to the parameter
    # 
    # @params id [Integer] the Id of a specific user
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of the monster
    #   * :Name [String] the name of the monster
    #   * :Age [Integer] the age of the monster
    #   * :Fed [String] the fed status of the monster
    #   * :UserId [Integer] the Id of the owner user
    #   * :ImageLink [String] the link to the monster's image
    #   * :Description [String] the description of the monster
    #   * :SoldStatus [Integer] the sold status of the monster
    def user_monsters(id)
        return $db.execute("SELECT * FROM monsters WHERE UserId = ?", id)
    end

    # Select all the information of one entry with the corresponding Id to the parameter
    # 
    # @params id [Integer] the Id of a specific monster
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of the monster
    #   * :Name [String] the name of the monster
    #   * :Age [Integer] the age of the monster
    #   * :Fed [String] the fed status of the monster
    #   * :UserId [Integer] the Id of the owner user
    #   * :ImageLink [String] the link to the monster's image
    #   * :Description [String] the description of the monster
    #   * :SoldStatus [Integer] the sold status of the monster
    def monster(id)
        return $db.execute("SELECT * FROM monsters WHERE Id = ?", id).first
    end

    # Selects the monsters Types and Type Ids using inner join on the monsters, types, and monsters_types_rel tables with the corresponding Monster Ids to the parameter
    # 
    # @params id [Integer] the Id of a specific monster
    # 
    # @return [Hash]
    #   * :TypeId [Integer] the Id of the type
    #   * :Type [String] the name of the type
    def monsters_types(id)
        return $db.execute("SELECT monsters_types_rel.TypeId, types.Type FROM monsters_types_rel INNER JOIN monsters ON monsters_types_rel.MonsterId = monsters.Id INNER JOIN types ON monsters_types_rel.TypeId = types.Id WHERE monsters.Id = ?", id)
    end

    # Attempts to insert a new entry into the monsters table, and corresponding information in the many to many table for monsters types, monsters_types_rel
    def new_monster()
        $db.execute("INSERT INTO monsters (Name, Age, Fed, UserId, Description, SoldStatus) VALUES (?, ?, ?, ?, ?, ?)", @name, @age, @fed, @userid, @desc, @sold)
        id = $db.execute("SELECT last_insert_rowid()")
        id = id[0]["last_insert_rowid()"]
        $db.execute("INSERT INTO monsters_types_rel (TypeId, MonsterId) VALUES (?, ?)", @type1, id)
        $db.execute("INSERT INTO monsters_types_rel (TypeId, MonsterId) VALUES (?, ?)", @type2, id)
    end

    # Selects the previous TypeId for a monster with the corresponding id to the parameter
    # 
    # @params id [Integer] the Id of a specific monster
    # 
    # @return [Hash]
    #  * :TypeId [Integer] the Id of the monster's type
    def previous_types_monster(id)
        return $db.execute("SELECT TypeId FROM monsters_types_rel WHERE MonsterId = ?", id)
    end

    # Attempts to update an entry in the monster table, as well as the many to many table monsters_types_rel
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

    # Attempts to delete an entry in the monster table
    # 
    # @params id [Integer] the Id of a specific monster
    def delete_monster(id)
        $db.execute("DELETE FROM monsters WHERE id = ?", id)
    end

    # Attemtps to select all the information of all entries in the foods table
    # 
    # @params id [Integer] the Id of a specific monster
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of each food
    #   * :Name [String] the name of each food
    #   * :Description [String] the description of each food
    def all_foods(id)
        return $db.execute("SELECT * FROM foods")
    end

    # Selects the amount of food, the name, the Id and the description of the food the user has from the foods and users_foods_rel tables, the food's id, name and description from all entries where the UserId corresponds to the given parameter
    # 
    # @params id [Integer] the Id of a specific monster
    # 
    # :@return [Hash]
    #   * :FoodAmount [Integer] the amount of food registered to a user
    #   * :Id [Integer] the Id of each food 
    #   * :Name [String] the name of the food 
    #   * :Description [String] the description of the food 
    def user_foods(id)
        return $db.execute("SELECT FoodAmount, foods.Id, Name, Description FROM users_foods_rel INNER JOIN foods ON foods.Id = users_foods_rel.FoodId WHERE UserId = ?", id)
    end

    # Selects all entries with the corresponding foodid to the given parameter, selecting the id, name, description and food amount registered to the user. If the user is an admin, it selects the total amount of food instead of the amount registered to the user.
    # 
    # @params id [Integer] the Id of a specific user
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of each food 
    #   * :Name [String] the name of the food 
    #   * :Description [String] the description of the food 
    #   * :FoodAmount [Integer] the amount of food registered to a user
    # @return [Hash] if the user is an Admin
    #   * :Id [Integer] the Id of each food 
    #   * :Name [String] the name of the food 
    #   * :Description [String] the description of the food 
    #   * :MarketAmount [Integer] the amount of food in total
    def food(id)
        if userresult['Admin'] == "Admin"
            return $db.execute("SELECT foods.Id, foods.name, foods.Description, market_foods.MarketAmount FROM foods INNER JOIN market_foods ON market_foods.FoodId = foods.Id WHERE foods.Id = ?", id).first
        else
            return $db.execute("SELECT foods.Id, foods.name, foods.Description, users_foods_rel.FoodAmount FROM foods INNER JOIN market_foods ON market_foods.FoodId = foods.Id INNER JOIN users_foods_rel ON users_foods_rel.FoodId = foods.Id WHERE foods.Id = ? AND UserId = ?", id, userresult['Id']).first
        end
    end

    # Selects the typeid and type name from the foods, types, and foods_types_rel tables where the foodid corresponds to the given parameter
    # 
    # @params id [Integer] the Id of a specific food
    # 
    # @return [Hash]
    #   * :TypeId [Integer] the Id of the type
    #   * :Type [String] the name of the type
    def food_types(id)
        return $db.execute("SELECT foods_types_rel.TypeId, types.Type FROM foods_types_rel INNER JOIN foods ON foods_types_rel.FoodId = foods.Id INNER JOIN types ON foods_types_rel.TypeId = types.Id WHERE foods.Id = ?", id)
    end

    # Attempts to insert a new entry into the food table, as well as the many to many table foods_types_rel
    def new_food()
        $db.execute("INSERT INTO foods (Name, Description) VALUES (?, ?)", @name, @desc)

        id = $db.execute("SELECT last_insert_rowid()")
        id = id[0]["last_insert_rowid()"]

        $db.execute("INSERT INTO foods_types_rel (TypeId, FoodId) VALUES (?, ?)", @type1, id)
        $db.execute("INSERT INTO foods_types_rel (TypeId, FoodId) VALUES (?, ?)", @type2, id)
        $db.execute("INSERT INTO foods_types_rel (TypeId, FoodId) VALUES (?, ?)", @type3, id)
        $db.execute("Insert INTO market_foods (FoodId, MarketAmount) VALUES (?, ?)", id, @amount)
    end

    # Selects the typeid of the food's previous types
    # 
    # @params id [Integer] the Id of a specific food
    # 
    # @return [Hash]
    #   * :TypeId [Integer] the Id of the type
    def previous_types_food(id)
        return $db.execute("SELECT TypeId FROM foods_types_rel WHERE FoodId = ?", id)
    end

    # Attempts to update an entry in the foods and/or foods_types_rel tables
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

    # Attempts to delete an entry from the foods table where the food id corresponds to the given parameter
    # 
    #   * :TypeId [Integer] the Id of the food
    def delete_food(id)
        $db.execute("DELETE FROM foods WHERE id = ?", id)
    end

    # Selects all information from all entries in the toys table
    # 
    # @param id [Integer] the Id of the toy
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of each toy
    #   * :Name [String] the name of each toy
    #   * :Description [String] the description of each toy
    #   * :TypeId [Integer] the id of the type of each toy
    #   * :UserId [Integer] the id of the owner user of each toy
    #   * :Soldstatus [Integer] the sold status of each toy
    def all_toys()
        return $db.execute("SELECT * FROM toys")
    end

    # Selects all the information of entries in the toys table where the id corresponds to the given parameter
    # 
    # @param id [Integer] the Id of the toy
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of each toy
    #   * :Name [String] the name of each toy
    #   * :Description [String] the description of each toy
    #   * :TypeId [Integer] the id of the type of each toy
    #   * :UserId [Integer] the id of the owner user of each toy
    #   * :Soldstatus [Integer] the sold status of each toy
    def user_toys(id)
        return $db.execute("SELECT * FROM toys WHERE UserId = ?", id)
    end

    # Selects the Id, Name, Description, Typeid, UserId and Type name of a specific entry in the toys inner joined types tables where the id corresponds to the given parameter
    # 
    # @param id [Integer] the Id of the toy
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of the toy
    #   * :Name [String] the name of the toy
    #   * :Description [String] the description of the toy
    #   * :TypeId [Integer] the id of the type of the toy
    #   * :UserId [Integer] the id of the owner user of the toy
    #   * :Type [String] the name of the type
    def toy(id)
        return $db.execute("SELECT toys.Id, toys.Name, toys.Description, toys.TypeId, toys.UserId, types.Type FROM toys INNER JOIN types ON types.Id = toys.TypeId WHERE toys.Id = ?", id).first
    end

    # Attempts to insert a new entry into the toys table
    def new_toy()
        $db.execute("INSERT INTO toys (Name, Description, TypeId, Solstatus) VALUES (?, ?, ?, ?)", @name, @desc, @type, @sold)
    end

    # Attempts to update an entry in the toys table
    def update_toy()
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

    # Attempts to delete an entry in the toys table where the id corresponds to the given parameter
    # 
    # @param id [Integer] the Id of the toy
    def delete_toy(id)
        $db.execute("DELETE FROM toy WHERE id = ?", id)
    end

    # Selects all information for all entries in the monsters table where the sold status is 1, aka being sold
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of each monster
    #   * :Name [String] the name of each monster
    #   * :Age [Integer] the age of each monster
    #   * :Fed [String] the fed status of each monster
    #   * :UserId [Integer] the Id of the owner user
    #   * :ImageLink [String] the link to each monster's image
    #   * :Description [String] the description of each monster
    #   * :SoldStatus [Integer] the sold status of each monster
    def sold_pets()
        return $db.execute("SELECT * FROM monsters WHERE SoldStatus = 1")
    end

    # Selects all information for all entries in the toys table where the sold status is 1, aka being sold
    # 
    #  @return [Hash]
    #   * :Id [Integer] the Id of each toy
    #   * :Name [String] the name of each toy
    #   * :Description [String] the description of each toy
    #   * :TypeId [Integer] the id of the type of each toy
    #   * :UserId [Integer] the id of the owner user of each toy
    #   * :Soldstatus [Integer] the sold status of each toy
    def sold_toys()
        return $db.execute("SELECT * FROM toys WHERE SoldStatus = 1")
    end

    # Selects the Id, Name, Description and Market Amount for all entries in the monsters and inner joined market_foods tables, as all foods are sold
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of each food 
    #   * :Name [String] the name of the food 
    #   * :Description [String] the description of the food 
    #   * :MarketAmount [Integer] the amount of food in total
    def sold_foods()
        return $db.execute("SELECT foods.Id, foods.name, foods.Description, market_foods.MarketAmount FROM foods INNER JOIN market_foods ON foods.Id = market_foods.FoodId")
    end

    # Attempts to delete a user's food from the users_foods_rel table where the FoodId and UserId correspond to the given parameters
    # 
    # @param id [Integer] the Id of the food
    # @param userid [Integer] the Id of the user
    def remove_user_food(id, userid)
        $db.execute("DELETE FROM users_foods_rel WHERE FoodId = ? AND UserId = ?", id, userid)
    end

    # Selects the id, name, description and market amount of the specific entry in the foods and market_foods tables using inner join, where the foodid corresponds to the given parameter
    # 
    # @param id [Integer] the Id of the food
    # 
    # @return [Hash]
    #   * :Id [Integer] the Id of each food 
    #   * :Name [String] the name of the food 
    #   * :Description [String] the description of the food 
    #   * :MarketAmount [Integer] the amount of food in total
    def market_food(id)
        return $db.execute("SELECT foods.Id, foods.name, foods.Description, market_foods.MarketAmount FROM foods INNER JOIN market_foods ON market_foods.FoodId = foods.Id WHERE foods.Id = ?", id).first
    end

    # Attempts to update the purchased item provided the user is not an admin, and sets the userid to the user's id and the sold status to 0. If the purchased item is a food, the total amount is decreased, and added to the users already existing amount if they already had an entry.
    # 
    # # @param id [Integer] the Id of the item
    def purchase(id)
        userid = userresult['Id']

        if userresult['Admin'] != "Admin"
            if @purchased_item == "monster"
                $db.execute("UPDATE monsters SET UserId = ?, SoldStatus = 0 WHERE Id = ?", userid, id)
            elsif @purchased_item == "toy"
                $db.execute("UPDATE toys SET UserId = ?, SoldStatus = 0 WHERE Id = ?", userid, id)
            else
                if $db.execute("SELECT * FROM users_foods_rel WHERE FoodId = ? AND UserId = ?", id, userid).first
                    old_amount_user =  $db.execute("SELECT FoodAmount FROM users_foods_rel WHERE FoodId = ? AND UserId = ?", id, userid).first
                    old_amount_user = old_amount_user['FoodAmount'].to_i
                    @amount += old_amount_user
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

    # Attempts to update the sold status of the sold item, where the sold items id corresponds to the given parameter, validating with the user's id that they own the item being sold, or being sent an error message
    # 
    #     # # @param id [Integer] the Id of the item
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
end