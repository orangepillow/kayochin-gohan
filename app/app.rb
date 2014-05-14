require 'bundler'
Bundler.require
require 'digest/md5'
require 'rack-flash'

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
      @filters = ImageFilter::FILTERS
      slim :index
    end

    get '/takitate' do
      generated_image = Generated::Image.new(params)
      generated_image.exist? && show_takitate(generated_image.url_path)

      begin
        generated_image.write
      rescue OpenURI::HTTPError => e
        msg = '指定したURLの画像は存在しません' if e.message == '404 Not Found'
      rescue MiniMagick::Invalid
        msg = '指定したURLは画像ではありません。画像のURLを入力してください'
      rescue Downloaded::Invalid
        white_list = Downloaded::Image::WHITE_LIST
        msg = "指定できない画像形式です(指定可能: #{white_list})"
      rescue Character::Invalid
        msg = '指定したキャラクターは存在しません'
      end

      redirect_with_flash_error(msg) if msg

      show_takitate(generated_image.url_path)
    end

    def show_takitate(url_path)
      @path = url_path
      slim :takitate
    end

    def redirect_with_flash_error(msg)
      flash[:error] = msg
      @filters = ImageFilter::FILTERS
      redirect '/'
    end
  end
end

module Generated
  STORE_DIR = 'images/build'
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

      @filename_seed = [
        @url, @character, @flip, @filter, @gravity, @scale, @percentage
      ].join
    end

    def filename
      Digest::SHA1.new.update(@filename_seed).to_s + File.extname(@url)
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
      resize?(s) ? s : 'natural'
    end

    def resize?(scale)
      %w(resize maximize).include?(scale)
    end

    def resized_dimensions(base, chara, scale, percentage)
      case scale
      when 'maximize'
        base.image[:dimensions]
      when 'resize'
        base.image[:dimensions].map { |s| (s * percentage / 100).ceil }
      else
        chara.image[:dimensions]
      end
    end

    def reverse(image)
      image.flop if @flip
      image.flip if @gravity.include?('north')
    end

    def resize(base, chara, scale, percentage)
      if resize?(scale)
        cols, rows = resized_dimensions(
          base, chara, scale, percentage)
        chara.image.resize "#{cols}x#{rows}"
      end
    end

    def write
      downloaded = Downloaded::Image.new(@url)
      character = Character::Image.new(@character)

      reverse(character.image)
      resize(downloaded, character, @scale, @percentage)

      image = downloaded.image.composite(character.image) do |c|
        c.gravity @gravity
      end

      image = ImageFilter.apply(image, @filter)
      image.write(filepath)
    end
  end
end

module Downloaded
  class Invalid < StandardError; end

  class Image
    WHITE_LIST = %w(image/jpeg image/png image/gif)
    attr_reader :image

    def initialize(url)
      @image = MiniMagick::Image.open(url)
      fail Downloaded::Invalid unless self.valid?
    end

    def valid?
      WHITE_LIST.include?(@image.mime_type)
    end
  end
end

module Character
  class Invalid < StandardError; end

  class Image
    STORE_DIR = KayochinGohan::PUBLIC_ROOT + '/' + 'images/characters'
    attr_reader :image

    def initialize(name)
      @name = name
      fail Character::Invalid unless self.exist?
      @image = MiniMagick::Image.open(image_path, 'png')
    end

    def image_path
      STORE_DIR + '/' + @name.to_s + '.png'
    end

    def exist?
      File.exist?(image_path)
    end
  end
end

class ImageFilter
  FILTERS = %w(none grayscale sepia toaster gotham lomo kelvin)

  def self.apply(image, name)
    if self.exist?(name)
      image = send(filter_method(name), image)
    else
      image
    end
  end

  def self.exist?(name)
    self.methods.map{ |m| m.to_s }.include?(filter_method(name))
  end

  def self.filter_method(name)
    "#{name}_filter"
  end

  def self.grayscale_filter(image)
    image.colorspace('Gray')
    image
  end

  def self.sepia_filter(image)
    image.sepia_tone '80%'
    image
  end

  def self.toaster_filter(image)
    new_image = image.clone
    new_image.combine_options do |cmd|
      cmd.fill '#330000'
      cmd.colorize '63%'
    end
    image = image.composite new_image do |cmd|
      cmd.compose 'blend'
      cmd.define 'compose:args=100,0'
    end

    image.modulate '150,80,100'
    image.gamma 1.2
    image.contrast
    image.contrast
    image
  end

  def self.gotham_filter(image)
    image.modulate '120,10,100'
    image.fill '#222b6d'
    image.colorize 20
    image.gamma 0.5
    image.contrast
    image
  end

  def self.lomo_filter(image)
    image.channel 'R'
    image.level '22%'
    image.channel 'G'
    image.level '22%'
    image
  end

  def self.kelvin_filter(image)
    cols, rows = image[:dimensions]

    image.auto_gamma
    image.modulate '120,50,100'

    new_image = image.clone
    new_image.combine_options do |c|
      c.fill 'rgba(255, 153, 0, 0.5)'
      c.draw "rectangle 0,0 #{cols},#{rows}"
    end

    image = image.composite new_image do |c|
      c.compose 'multiply'
    end

    image.gamma 1.2
    image
  end
end
