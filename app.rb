#main controller
require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require 'sqlite3'
require_relative 'model' # should work, double check

enable :sessions

get('/') do
    slim(:index)
end

#could users be restful:d??
get('/log_in') do
    slim(:log_in)
end

post('/log_in') do
    username = params[:username]
    password = params[:password]


end

get('/register_user') do
    slim(:register_user)
end

