require 'mini_magick'

class ImageFilter
  FILTERS = %w(none grayscale sepia toaster gotham lomo kelvin blur)

  def self.apply(image, name)
    if self.exist?(name)
      image = send(filter_method(name), image)
    else
      image
    end
  end

  def self.exist?(name)
    methods.map { |m| m.to_s }.include?(filter_method(name))
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

  def self.blur_filter(image)
    cols, rows = image[:dimensions]

    new_image = image.clone
    new_image.combine_options do |c|
      c.fill 'rgba(255, 255, 255, 0.5)'
      c.draw "rectangle 0,0 #{cols},#{rows}"
    end

    image = image.composite new_image do |c|
      c.compose 'multiply'
    end

    image.blur '0x8'
    image
  end
end
