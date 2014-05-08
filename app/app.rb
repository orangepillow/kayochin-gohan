require 'bundler'
Bundler.require

module KayochinGohan
  class App < Sinatra::Base
    configure :development do
      Slim::Engine.set_default_options pretty: true
      register Sinatra::Reloader
    end

    get '/' do
      slim :index
    end

    get '/takitate' do

    end
  end
end
