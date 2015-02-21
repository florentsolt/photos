module Lib
class Photo

  FORMAT = "%05d"
  SIZES = [:original, :resize, :preview]

  def self.from_uri(uri)
    uri.strip!
    uri = uri[1..-1] if uri[0] == '/'
    name, id = uri.split('/')
    Album.load(name).photos[id]
  end

  def initialize(album, id, ext = false)
    @album = album
    @id = id
    @ext = ext || @album.photos[@id].ext || 'jpg'
    @sizes = {}
    @exif = nil
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
    when :resize
      "resize-#{@id}.#{@ext}"
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

  def exif(raw = false)
    if raw
      JSON.load(`exiftool -j '#{filename(:original)}'`).first
    else
      @exif
    end
  end

  def exif!(force = false)
    if force or @exif.nil?
      puts "Extract EXIF from #{File.basename(filename(:original))}"
      exif = JSON.load(`exiftool -j '#{filename(:original)}'`).first

      time = exif["DateTimeOriginal"] || exif["DateTimeCreated"] || exif["CreateDate"] || exif["DigitalCreationDateTime"] || ""
      time = Time.new *(time.scan(/\d+/).collect{|d| d.to_i})

      @exif = Exif.new(
        exif["FocalLength"].to_i, # focal
        exif["ShutterSpeedValue"] || 0, # speed
        exif["ApertureValue"] || 0, # aperture
        exif["ISO"].to_i, #iso 
        time.to_i # time
      )
    end
  end

  def optimize!
    return if @optimized
    [:resize, :preview].each do |size|
      Optimize.file(filename(size))
    end
    @optimized = true
  end

  def thumbs!(force = false)
    require 'image_sorcery'

    quality = @album.config(:quality)
    resize = @album.config(:size)
    preview = @album.config(:preview)

    image = ImageSorcery.gm(filename(:original))

    if not File.exists? filename(:resize) or force
      image.convert(filename(:resize), quality: quality, thumbnail: "#{resize}x")
      puts "Create #{File.basename(filename(:resize))}"
    end

    if not File.exists? filename(:preview) or force
      image.convert(filename(:preview), quality: quality, scale: preview)
      puts "Create #{File.basename(filename(:preview))}"
    end
  end

  def clear!(keep_originals = false)
    files = [filename(:resize), filename(:preview)]
    files << filename(:original) if not keep_originals
    files.each do |file|
      if File.exists? file
        puts "Delete #{File.basename(file)}"
        File.unlink file
      end
    end
  end

  def next
    index = @album.photos.keys.index(@id)
    @album.photos.values[index + 1] || @album.photos.values.first
  end

  def prev
    index = @album.photos.keys.index(@id)
    @album.photos.values[index - 1] || @album.photos.values.last
  end
 
end
end
