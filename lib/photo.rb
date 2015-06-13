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

  def optimize!
    return if @optimized
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

    if not File.exists? filename(:thumb) or force
      image.convert(filename(:thumb), quality: quality, thumbnail: "x#{thumb}^")
      puts "Create #{File.basename(filename(:thumb))}"
    end

    if not File.exists? filename(:preview) or force
      image.convert(filename(:preview), quality: quality, scale: preview)
      puts "Create #{File.basename(filename(:preview))}"
    end
  end

  def clear!(keep_originals = false)
    files = [filename(:thumb), filename(:preview)]
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
