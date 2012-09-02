require 'sinatra'
require 'erb'

  set :static, true
  set :public_folder, File.dirname(__FILE__) + '/public'

  get '/' do
     edh_metadata = File.open("public/epapers/edh_metadata.txt", "r")
     lpg_metadata = File.open("public/epapers/lpg_metadata.txt", "r")
     @edh_page = edh_metadata.readline
     @edh_date = edh_metadata.readline
     @edh_size = edh_metadata.readline
     @lpg_page = lpg_metadata.readline
     @lpg_date = lpg_metadata.readline
     @lpg_size = lpg_metadata.readline
     erb :index
  end

