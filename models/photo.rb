module Model
class Photo

  FORMAT = "%05d"

  class << self

    def from_uri(uri)
      uri.strip!
      uri = uri[1..-1] if uri[0] == '/'
      name, id = uri.split('/')
      Photo.new(Stream.new(name), id)
    end
  end

  def initialize(stream, id, ext = false)
    @stream = stream
    @id = id
    @ext = ext || @stream.ids[@id] || 'jpg'
    if not @stream.ids.key? @id or @stream.ids[@id] != @ext
        throw "Photo id #{id.inspect} does not exists"
    end
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
    @stream.name / case type
    when :original
      "#{@stream.name}-#{@id}.#{@ext}"
    when :square
      "square-#{@id}.#{@ext}"
    when :resize
      "resize-#{@id}.#{@ext}"
    when :preview
      "preview-#{@id}.#{@ext}"
    else
      throw "Unknown file type #{type.inspect}"
    end
  end

  def filename(type)
    Stream::PATH / uri(type)
  end

  class Size
    def initialize(name, type, id)
      @name = name
      @type = type
      @id = id
    end

    def x
      DB.hget "sizes.#{@name}", "#{@type}.#{@id}.x"
    end

    def y
      DB.hget "sizes.#{@name}", "#{@type}.#{@id}.y"
    end
  end

  def size(type)
    Size.new(@stream.name, type, id)
  end

  def exif(raw = false)
    if raw
      JSON.load(`exiftool -j '#{filename(:original)}'`).first
    else
      DB.hgetall "exif.#{@stream.name}.#{@id}"
    end
  end

  def next
    return @next if not @next.nil?
    index = @stream.ids.keys.index(@id)
    id = @stream.ids.keys[index + 1] || @stream.ids.keys.first
    @next = Photo.new @stream, id, @stream.ids[id]
  end

  def prev
    return @prev if not @prev.nil?
    index = @stream.ids.keys.index(@id)
    id = @stream.ids.keys[index - 1] || @stream.ids.keys.last
    @prev = Photo.new @stream, id, @stream.ids[id]
  end
 
  def time
    return @time if not @time.nil?
    @time = Time.at DB.hget("exif.#{@stream.name}.#{@id}", "time").to_i
  end

end
end
