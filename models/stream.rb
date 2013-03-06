module Model
class Stream
  PATH = Model::CONFIG['path']

  @@cache = {}

  class << self
    def default(name)
      Model::CONFIG[name.to_s]
    end

    def each(sort = false)
      return if not block_given?
      streams = Dir[PATH / '*'].collect do |dir|
        if File.directory? dir and File.exists? dir / 'config.yml'
          Stream.new(File.basename(dir))
        end
      end.compact

      case sort
        when "name"
          streams.sort!{|a,b| a.name <=> b.name}
        when "title"
          streams.sort!{|a,b| a.config(:title) <=> b.config(:title)}
        when "time", "times", "date", "dates"
          streams.sort!{|a,b| b.times[:min].to_i <=> a.times[:min].to_i}
      end

      streams.each do |stream|
        yield stream
      end
    end
  end

  module Index
    def self.protected?
      not Model::Stream.default(:index).nil? and not Model::Stream.default(:index)["password"].nil?
    end

    def self.password
      self.protected? && Model::Stream.default(:index)["password"]
    end

    def self.sort
      if not Model::Stream.default(:index).nil?
        Model::Stream.default(:index)["sort"]
      else
        false
      end
    end
  end

  def initialize(name)
    @name = File.basename(name)
    throw "Unknown photostream #{@name}" if not File.exists? PATH / @name / 'config.yml'
  end

  def name
    @name
  end

  def config(name)
    if @config.nil?
      # load and merge
      @config = Model::CONFIG.merge YAML.load_file(PATH /  @name / 'config.yml')

      # cleanup "section" key
      if @config.key? 'section'
        sections_with_ids = {}
        @config['section'].each do |k,v|
          sections_with_ids[Photo::FORMAT % k.to_i] = v
        end
        @config['section'] = sections_with_ids
      end
    end
    @config[name.to_s]
  end

  def protected?
    config(:password) && true || false
  end

  def font_family
    family = config(:font).strip
    family = CGI.unescape(family) if family.include? '+'
    family.split(':').first
  end

  def font_href
    family = config(:font).strip
    family = CGI.escape(family) if family.include? ' '
    "http://fonts.googleapis.com/css?family=#{family}"
  end

  def etag
    "#{File.mtime(PATH /  @name / 'config.yml').to_i}-#{Time.now.strftime "%Y%m%d"}-#{Digest::SHA1.hexdigest(config(:password).to_s)}"
  end

  def photos
    @photos ||= ids.collect{|id,ext| Photo.new self, id, ext}
  end 

  def samples
    PATH / @name / 'samples.png'
  end

  def sets
    urls = config(:set)
    urls = [urls] if not urls.is_a? Array
    @sets ||= urls.collect do |url|
      Set.new self, url
    end
  end

  def download!
    require 'curb'
    files = []
    urls = []
    sets.each do |set|
      set.photos.each do |photo|
        # Cache flickr urls/ids for stats
        if photo =~ %r|http://farm(\d+)\.staticflickr\.com/([a-f\d]+)/([a-f\d]+)_([a-f\d]+)_o\.jpg|i
          # $1 = farm, $2 = server, $3 = id, $4 = secret
          # files.sizes = photo id
          DB.hset "flickr", [$1, $2, $3].join("-"), "#{@name}/#{Photo::FORMAT % files.size}"
        end

        files << basename = File.basename(photo)
        filename = "#{@name}-#{Photo::FORMAT % files.index(basename)}.jpg"

        photo = URI.parse photo
        if not File.exists? PATH / @name / filename
          urls << photo
        elsif photo.scheme == 'file'
          system "rm '#{photo.path}'"
        end
      end
    end

    files.each_index do |i|
      # TODO instead of using the index for the score
      # use a conf to specify upload order or date taken or both reversed

      DB.zadd "photos.#{@name}", i, (Photo::FORMAT % i) + File.extname(files[i])
    end

    if not urls.empty?
      urls.each do |url|
        if url.scheme == 'file'
          filename = "#{@name}-#{Photo::FORMAT % files.index(File.basename(url.to_s))}#{File.extname(url.to_s)}"
          puts "Move #{url.path} in #{filename}"
          system "mv '#{url.path}' '#{PATH / @name / filename}'"
        else
          http = Curl::Easy.perform(url.to_s) do |curl|
            curl.follow_location = true
            curl.resolve_mode = :ipv4
            curl.on_success do |easy|
              filename = "#{@name}-#{Photo::FORMAT % files.index(File.basename(easy.url))}.jpg"
              puts "Download #{easy.url} in #{filename}"
              File.open(PATH / @name / filename, 'w:BINARY') do |fd|
                fd.puts easy.body_str
              end
            end
          end
        end
      end
    end
  end

  def thumbs!(force = false)
    require 'image_sorcery'
    size = "#{config(:size)}x#{config(:size)}"

    ids.each do |id,ext|
      photo = Photo.new(self, id, ext)
      image = Sorcery.gm(photo.filename(:original))

      if not File.exists? photo.filename(:resize) or force
        image.convert(photo.filename(:resize), quality: config(:quality), scale: "#{config(:size)}x")
        puts "Thumbify #{photo.filename(:resize)}"
      end

      if not File.exists? photo.filename(:square) or force
        image.convert(photo.filename(:square), quality: config(:quality), thumbnail: "#{size}^", gravity: "center", extent: size)
        puts "Thumbify #{photo.filename(:square)}"
      end

      if not File.exists? photo.filename(:preview) or force
        image.convert(photo.filename(:preview), quality: config(:quality), scale: "#{config(:preview)}")
        puts "Thumbify #{photo.filename(:preview)}"
      end
    end
  end

  def samples!(force = false)
    require 'image_sorcery'
    
    if not File.exists? self.samples or force
      if photos.count <= 5
        keys = []
        0.upto(4) do |i|
          keys << i % photos.count
        end
      else
        size = photos.count / 5
        middles = [
          0..(size - 1),
          size..(size*2 - 1),
          (size*2)..(size*3 - 1),
          (size*3)..(size*4 - 1),
          (size*4)..(ids.count - 1)
        ].collect do |range|
          range.first + (range.last - range.first) / 2
        end
        keys = (0..4).to_a.collect{|i| size / 2 + size * i}
      end
      samples = photos.values_at(*keys)

      image = Sorcery.gm(self.samples)
      image.montage(samples.collect{|s| PATH / s.uri(:square)},
                    background: '#000000FF', tile: '5x1', geometry: '50x50',
                    borderwidth: 1, bordercolor: '#000000FF', frame: '0x0+0+0')
    end
  end

  def sizes!(force = false)
    require 'image_sorcery'
    
    key = "sizes.#{@name}"
    DB.del key if force

    ids.each do |id,ext|
      photo = Photo.new(self, id, ext)
      { :original => photo.filename(:original),
        :resize => photo.filename(:resize),
        :square => photo.filename(:square),
        :preview => photo.filename(:preview)
      }.each do |type, filename|
        field = "#{type}.#{photo.id}"
        if not DB.hexists(key, "#{field}.x") and File.exists? filename
          puts "Sizing #{filename}"
          image = Sorcery.gm(filename)
          DB.hset key, "#{field}.x", image.dimensions[:x]
          DB.hset key, "#{field}.y", image.dimensions[:y]
        end
      end
    end
  end

  def exif!(force = false)
    ids.each do |id,ext|
      photo = Photo.new(self, id, ext)
      key = "exif.#{@name}.#{photo.id}"
      if not DB.exists key or force
        DB.del key
        puts "Extract EXIF from #{photo.filename(:original)}"
        exif = JSON.load(`exiftool -j '#{photo.filename(:original)}'`).first

        time = exif["DateTimeOriginal"] || exif["DateTimeCreated"] || exif["CreateDate"] || exif["DigitalCreationDateTime"] || ""
        time = Time.new *(time.scan(/\d+/).collect{|d| d.to_i})

        keep = {
          :focal => exif["FocalLength"].to_i,
          :speed => exif["ShutterSpeedValue"] || 0,
          :aperture => exif["ApertureValue"] || 0,
          :iso => exif["ISO"],
          :time => time.to_i
        }
        DB.hmset key, keep.flatten
      end
    end
  end

  def times!(force = false)
    key = "times.#{@name}"
    if not DB.exists key or force
      DB.del key
      times = photos.collect {|photo| photo.time.to_i}
      times.delete_if {|time| time == 0}
      DB.hmset key, :max, times.max, :min, times.min
    end
  end

  def times
    if @times.nil?
      key = "times.#{@name}"
      if not DB.exists key
        @times = {}
      else
        data = DB.hgetall key
        @times = {
          :min => Time.at(data["min"].to_i),
          :max => Time.at(data["max"].to_i),
        }
      end
    end
    @times
  end

  def zip!
    system "cd #{PATH / @name}; zip -u -X -D -0 archive.zip #{@name}-*.jpg #{@name}-*.gif #{@name}-*.png" if config(:zip)
  end

  def zip
    'archive.zip'
  end

  def optimize!
    key = "optimize.#{@name}"

    Dir[PATH / @name / "{square,resize,preview}-*.jpg"].each do |photo|
      basename = File.basename(photo)
      next if DB.sismember key, basename
      puts "Optimize #{basename}"
      system "jpegtran -optimize -copy none -progressive -outfile '#{photo}' '#{photo}'"
      DB.sadd key, basename
    end

    Dir[PATH / @name / "*.png"].each do |photo|
      basename = File.basename(photo)
      next if DB.sismember key, basename
      puts "Optimize #{basename}"
      system "pngcrush -q '#{photo}' '#{photo}.new'; mv '#{photo}.new' '#{photo}'"
      DB.sadd key, basename
    end
  end

  def clear!(keep_files = false)
    keys = []
    keys << "photos.#{@name}"
    keys += DB.keys "sizes.#{@name}.*"
    keys << "optimize.#{@name}"
    keys += DB.keys "exif.#{@name}.*"
    keys << "times.#{@name}"
    DB.del *keys
    if not keep_files
      system "rm -vrf #{PATH / @name / '*.jpg'}"
      system "rm -vrf #{PATH / @name / '*.png'}"
      system "rm -vrf #{PATH / @name / '*.gif'}"
      system "rm -vrf #{PATH / @name / '*.zip'}"
    end
  end

  def ids
    return @ids if not @ids.nil?
    ids = DB.zrange "photos.#{@name}", 0, -1
    ids.sort!{|a,b| a <=> b}
    ids.reverse! if config(:sort) == 'reverse'
    @ids = {}
    ids.each do |id|
      num, ext = id.split('.')
      @ids[num] = ext || 'jpg'
    end
    @ids
  end

end
end
