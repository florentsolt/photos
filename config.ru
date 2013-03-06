require File.dirname(__FILE__) + "/application"
Sinatra::Application.set :run, false
Sinatra::Application.set :environment, :production
Sinatra::Application.set :root, File.dirname(__FILE__)
run Sinatra::Application 

