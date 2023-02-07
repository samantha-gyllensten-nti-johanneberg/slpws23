#relevant functions

def check_login(username, password)
    # all of this still needs encrypting, but has some validation
    #perhaps add a length check to see entered stuff isnt too long, maybe should be seperate function or in app.rb
    session[:error_log_in] = false

    #Compares username and password to already existing accounts
    checkuser = db.execute("SELECT * FROM users WHERE Username LIKE ? AND Password LIKE ?", username, password)

    if checkuser == []
        session[:error_log_in] = true
        redirect('/log_in')
    else
    session[:username] = params[:username]
    session[:log_in] = true
    
    #Finds the id of the logged in user
    id = db.execute("SELECT Id FROM users WHERE Username LIKE ? AND Password LIKE ?", username, password)
    session[:id] = id

    redirect('/')

    def connect_to_db(db)
        database = SQLite3::Database.new("#{db}")
        # db.results_as_hash = true #is this necessary?
    end