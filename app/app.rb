require 'bundler'
Bundler.require
require 'open-uri'
require 'digest/md5'
require 'rack-flash'

module KayochinGohan
  class App < Sinatra::Base
    enable :sessions
    use Rack::Flash

    configure :development do
      Slim::Engine.set_default_options pretty: true
      register Sinatra::Reloader
    end

    configure do
      mime_type :jpeg, 'image/jpeg'
    end

    get '/' do
      slim :index
    end

    get '/takitate' do
      url = params[:image_url]

      ext = File.extname(url)
      public_root = 'app/public'
      build_dir = 'images/build'
      filename = Digest::SHA1.new.update(url).to_s + ext
      filepath = public_root + '/' + build_dir + '/' + filename

      unless File.exist?(filepath)
        begin
          image = MiniMagick::Image.open(url)
          image.write(filepath)
        rescue OpenURI::HTTPError => e
          e.message == '404 Not Found' && flash[:error] = '指定したURLの画像は存在しません'
          redirect '/'
        else
          @path = build_dir + '/' + filename
          slim :takitate
        end
      end
    end
  end
end
