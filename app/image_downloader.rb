require 'mini_magick'

class ImageDownloader
  class Invalid < StandardError; end

  attr_reader :url, :image

  MIME_TYPE_WHITE_LIST = %w(image/jpeg image/png image/gif)

  def initialize(url)
    @url = url
  end

  def download
    @image = MiniMagick::Image.open(@url)
    fail ImageDownloader::Invalid unless valid?
    @image
  end

  def valid?
    MIME_TYPE_WHITE_LIST.include?(@image.mime_type)
  end
end
