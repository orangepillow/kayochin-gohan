require 'bundler'
Bundler.require
require 'open-uri'
require 'sinatra/reloader'
require 'digest/md5'
require 'rack-flash'

require File.join(File.dirname(__FILE__), 'image_filter.rb')
require File.join(File.dirname(__FILE__), 'image_downloader.rb')

module KayochinGohan
  PUBLIC_ROOT = 'app/public'

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
      @character_names = character_names
      @filters = ImageFilter::FILTERS
      slim :index
    end

    get '/takitate' do
      generated_image = Generated::Image.new(params)

      begin
        generated_image.write unless generated_image.exist?
      rescue OpenURI::HTTPError => e
        msg = '指定したURLの画像は存在しません' if e.message == '404 Not Found'
      rescue MiniMagick::Invalid
        msg = '指定したURLは画像ではありません。画像のURLを入力してください'
      rescue ImageDownloader::InvalidURLScheme
        msg = 'httpもしくはhttpsで始まるURLを入力してください'
      rescue ImageDownloader::Invalid
        white_list = ImageDownloader::MIME_TYPE_WHITE_LIST.map do |m|
          m.gsub(Regexp.new('image/'), '')
        end.join(', ')
        msg = "指定できない画像形式です(指定可能: #{white_list})"
      rescue Character::Invalid
        msg = '指定したキャラクターは存在しません'
      end

      redirect_with_flash_error(msg) if msg
      show_takitate(generated_image.url_path)
    end

    def character_names
      pattern = Character::Image::STORE_DIR + '/' + '*.png'
      Dir.glob(pattern).map { |f| File.basename f, '.png' }
    end

    def show_takitate(url_path)
      @path = url_path
      slim :takitate
    end

    def redirect_with_flash_error(msg)
      flash[:error] = msg
      redirect '/'
    end
  end
end

module Generated
  STORE_DIR = 'images/build'
  RESIZE_TYPE = %w(resize maximize)
  GRAVITIES = %w(north northwest northeast south southwest southeast)

  class Image
    def initialize(params)
      @url = params[:image_url]
      @character = params[:m]
      @flip = params[:reverse]
      @filter = validate_filter(params[:filter])
      @gravity = validate_gravity(params[:g])
      @scale = validate_scale(params[:scale])
      @percentage = validate_percentage(params[:p])
    end

    def filename_seed
      instance_variables.map { |sym| instance_variable_get(sym) }.join
    end

    def filename
      Digest::SHA1.new.update(filename_seed).to_s + File.extname(@url)
    end

    def filepath
      KayochinGohan::PUBLIC_ROOT + '/' + STORE_DIR + '/' + filename
    end

    def url_path
      STORE_DIR + '/' + filename
    end

    def exist?
      File.exist?(filepath)
    end

    def validate_filter(f)
      ImageFilter::FILTERS.include?(f) ? f : 'none'
    end

    def validate_gravity(g)
      GRAVITIES.include?(g) ? g : 'south'
    end

    def validate_percentage(p)
      return 40 if p.nil?
      p = p.to_i
      (p >= 1 && p <= 100) ? p : 40
    end

    def validate_scale(s)
      RESIZE_TYPE.include?(s) ? s : 'natural'
    end

    def resize?
      RESIZE_TYPE.include?(@scale)
    end

    def resized_dimensions(base_img, chara_img)
      case @scale
      when 'maximize'
        base_img[:dimensions]
      when 'resize'
        base_img[:dimensions].map { |s| (s * @percentage / 100).ceil }
      else
        chara_img[:dimensions]
      end
    end

    def reverse(image)
      image.flop if @flip
      image.flip if @gravity.include?('north')
    end

    def resize(base_img, chara_img)
      cols, rows = resized_dimensions(base_img, chara_img)
      chara_img.resize "#{cols}x#{rows}"
    end

    def write
      downloaded_image = ImageDownloader.new(@url).download
      character = Character::Image.new(@character)

      reverse(character.image)
      resize(downloaded_image, character.image) if resize?

      image = downloaded_image.composite(character.image) do |c|
        c.gravity @gravity
      end
      image.format('jpg')
      image.quality(80)

      image = ImageFilter.apply(image, @filter)
      image.write(filepath)
    end
  end
end

module Character
  class Invalid < StandardError; end

  class Image
    STORE_DIR = KayochinGohan::PUBLIC_ROOT + '/' + 'images/characters'
    attr_reader :image

    def initialize(name)
      @name = name.to_s
      fail Character::Invalid unless self.exist?
      @image = MiniMagick::Image.open(image_path, 'png')
    end

    def image_path
      STORE_DIR + '/' + @name + '.png'
    end

    def exist?
      File.exist?(image_path)
    end
  end
end
