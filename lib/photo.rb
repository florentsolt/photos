module Lib
class Photo

  FORMAT = "%05d"
  SIZES = [:original, :thumb, :preview]

  CACHE = File.join(__dir__, '..', 'public', 'cache')
  Dir.mkdir CACHE if not File.directory? CACHE

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
    case type
    when :original
      @album.name / "#{@album.name}-#{@id}.#{@ext}"
    when :thumb
      :cache / "#{@album.name}-thumb-#{@id}.#{@ext}"
    when :preview
      :cache / "#{@album.name}-preview-#{@id}.#{@ext}"
    else
      throw "Unknown file type #{type.inspect}"
    end
  end

  def filename(type)
    if type === :original
      @album.config(:path) / uri(type)
    else
      CACHE / '..' / uri(type)
    end
  end

  def timestamp
    require 'exifr'
    exif = EXIFR::JPEG.new(filename(:original))
    (exif.date_time_original || exif.date_time).to_i
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
    quality = @album.config(:quality)
    thumb = @album.config(:thumb)
    preview = @album.config(:preview)

    if not File.exists? filename(:preview) or force
      puts "Create #{File.basename(filename(:preview))}"
      system "vipsthumbnail -s #{preview} #{filename(:original)} -o #{filename(:preview)}[Q=#{quality}]"
    end

    if not File.exists? filename(:thumb) or force
      puts "Create #{File.basename(filename(:thumb))}"
      system "vipsthumbnail -s x#{(thumb * 1.5).to_i}  #{filename(:preview)} -o #{filename(:thumb)}[Q=#{quality}]"
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
