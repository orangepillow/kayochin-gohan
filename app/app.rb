require 'bundler'
Bundler.require
require 'open-uri'
require 'digest/md5'
require 'rack-flash'

module KayochinGohan
  class App < Sinatra::Base
    enable :sessions
    use Rack::Flash

    PUBLIC_ROOT = 'app/public'
    STORE_DIR = 'images/build'

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
      @url = params[:image_url]

      show_generated_image if File.exist?(generated_image_file_path)

      begin
        image = MiniMagick::Image.open(@url)
        unless mime_type_white_list.include?(image.mime_type)
          msg = "指定できない画像形式です(指定可能: #{mime_type_white_list})"
          redirect_with_flash_error(msg)
        end

        image.write(generated_image_file_path)

      rescue OpenURI::HTTPError => e
        if e.message == '404 Not Found'
          msg = '指定したURLの画像は存在しません'
          redirect_with_flash_error(msg)
        end
      rescue MiniMagick::Invalid
        msg = '指定したURLは画像ではありません。画像のURLを入力してください'
        redirect_with_flash_error(msg)
      end

      show_generated_image
    end

    def filename
      Digest::SHA1.new.update(@url).to_s + File.extname(@url)
    end

    def generated_image_file_path
      PUBLIC_ROOT + '/' + STORE_DIR + '/' + filename
    end

    def generated_image_file_url_path
      STORE_DIR + '/' + filename
    end

    def show_generated_image
      @path = generated_image_file_url_path
      slim :takitate
    end

    def mime_type_white_list
      %w(image/jpeg image/png image/gif)
    end

    def redirect_with_flash_error(msg)
      flash[:error] = msg
      redirect '/'
    end
  end
end
