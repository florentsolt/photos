module Lib
class Photo

  FORMAT = "%05d"
  SIZES = [:original, :thumb, :preview]

  def initialize(album, id, ext = false)
    @album = album
    @id = id
    @ext = ext || @album.photos[@id].ext || 'jpg'
    @sizes = {}
    @optimized = false
  end

  def id
    @id
  end

  def ext
    @ext
  end

  # Move all that code to filename, and implement uri (to be used instead of
  # thumbs helpers
  def uri(type)
    @album.name / case type
    when :original
      "#{@album.name}-#{@id}.#{@ext}"
    when :embedded
      "embedded-#{@id}.jpg"
    when :thumb
      "thumb-#{@id}.#{@ext}"
    when :preview
      "preview-#{@id}.#{@ext}"
    else
      throw "Unknown file type #{type.inspect}"
    end
  end

  def filename(type)
    @album.config(:path) / uri(type)
  end

  def timestamp
    require 'exifr'
    EXIFR::JPEG.new(filename(:original)).date_time.to_i
  end

  def size(type)
    @sizes[type]
  end

  def sizes!(force = false)
    require 'image_sorcery'
    SIZES.each do |size|
      if force or @sizes[size].nil?
        puts "Size #{File.basename(filename(size))}"
        image = ImageSorcery.gm(filename(size))
        @sizes[size] = Size.new(image.dimensions[:x], image.dimensions[:y])
      end
    end
    @sizes
  end

  def optimize!(force = false)
    return if @optimized and not force
    [:thumb, :preview].each do |size|
      Optimize.file(filename(size))
    end
    @optimized = true
  end

  def thumbs!(force = false)
    require 'image_sorcery'

    quality = @album.config(:quality)
    thumb = @album.config(:thumb)
    preview = @album.config(:preview)

    image = ImageSorcery.gm(filename(:original))
    if not File.exists? filename(:preview) or force
      puts "Create #{File.basename(filename(:preview))}"
      image.convert(filename(:preview), quality: quality, scale: preview)
    end

    image = ImageSorcery.gm(filename(:preview))
    if not File.exists? filename(:thumb) or force
      puts "Create #{File.basename(filename(:thumb))}"
      # double the thumb size for retina
      image.convert(filename(:thumb), quality: quality, thumbnail: "x#{(thumb * 1.5).to_i}^")
    end

    image = ImageSorcery.gm(filename(:thumb))
    if not File.exists? filename(:embedded) or force
      puts "Create #{File.basename(filename(:embedded))}"
      image.convert(filename(:embedded), quality: "10", colors: "50", thumbnail: "x42^")
      Optimize.jpg(filename(:embedded))
    end
  end

  def clear!(keep_originals = false)
    files = [filename(:thumb), filename(:preview), filename(:embedded)]
    files << filename(:original) if not keep_originals
    files.each do |file|
      if File.exists? file
        puts "Delete #{File.basename(file)}"
        File.unlink file
      end
    end
  end

end
end
