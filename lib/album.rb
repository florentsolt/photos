module Lib
  class Album

    @@cache = {}

    DUMP_FILE = "album.msh"

    def self.load(name)
      filename = Config.default(:path) / name / DUMP_FILE
      return @@cache[name] if @@cache.key? name

      if File.exists? filename
        @@cache[name] = Marshal.load(File.read(filename))
      else
        @@cache[name] = Album.new(name)
      end
    end

    def initialize(name)
      @name = File.basename(name)
      @times = Times.new
      @photos = {}
      throw "Unknown photo album #{@name}" if not File.directory? Config.default(:path) / @name
    end

    def dump
      File.open(config(:path) / @name / DUMP_FILE, 'w:BINARY') do |fd|
        fd.write Marshal.dump(self)
      end
    end

    def name
      @name
    end

    def config(name)
      Config.get(self, name)
    end

    def flickr?
      sets.each do |set|
        return true if set.flickr?
      end
      false
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

    def photos
      @photos
    end 

    def reverse?
      config(:sort).to_s == 'reverse'
    end

    def scan!
      @photos = {}
      Dir[Photo.new(self, '*', '{jpg,gif,png}').filename(:original)].sort.each do |file|
        file = File.basename(file)
        matches = file.match /^#{@name}-(\d{5})\.(.+)$/
        @photos[matches[1]] = Photo.new(self, matches[1], matches[2])
      end
      self.dump
    end

    def samples
      config(:path) / @name / 'samples.png'
    end

    def sets
      urls = config(:set)
      urls = [urls] if not urls.is_a? Array
      urls.collect do |url|
        Set.new self, url
      end
    end

    def download!
      require 'curb'
      files = []
      urls = []
      sets.each do |set|
        set.photos.each do |photo|
          files << basename = File.basename(photo)
          filename = "#{@name}-#{Photo::FORMAT % files.index(basename)}.jpg"

          url = URI.parse photo
          if not File.exists? config(:path) / @name / filename
            urls << url
          elsif url.scheme == 'file' and set.zip?
            # if it's not a new file, so it will not be moved or symlinked
            # in case of a zip, remove temp file
            File.unlink(url.host.to_s + url.path.to_s)
          end
        end
      end

      # new photos ?
      if not urls.empty?
        i = 0
        files.each do |file|
          id = Photo::FORMAT % i
          @photos[id] ||= Photo.new self, id, File.extname(file)[1..-1]
          i += 1
        end

        urls.each do |url|
          if url.scheme == 'file'
            filename = "#{@name}-#{Photo::FORMAT % files.index(File.basename(url.to_s))}#{File.extname(url.to_s)}"

            File.unlink(config(:path) / @name / filename) if File.exists?(config(:path) / @name / filename)

            # if files are in the same dir, then rename
            if File.dirname("#{url.host}#{url.path}") == config(:path) / @name
              puts "Move #{File.basename(url.path)} in #{filename}"
              File.rename "#{url.host}#{url.path}", config(:path) / @name / filename
            else
              # else only do a symlink
              puts "Symlink #{url.path} in #{filename}"
              File.symlink '..' / url.host / url.path, config(:path) / @name / filename
            end
          else
            http = Curl::Easy.perform(url.to_s) do |curl|
              curl.follow_location = true
              curl.resolve_mode = :ipv4
              curl.on_success do |easy|
                filename = "#{@name}-#{Photo::FORMAT % files.index(File.basename(easy.url))}.jpg"
                puts "Download #{easy.url} in #{filename}"
                File.open(config(:path) / @name / filename, 'w:BINARY') do |fd|
                  fd.puts easy.body_str
                end
              end
            end
          end
        end

        @times = Times.new
      end

      self.dump
    end

    def thumbs!(force = false)
      photos.each do |id, photo|
        photo.thumbs!(force)
      end
    end

    def samples!(force = false)
      require 'image_sorcery'

      if not File.exists? self.samples or force
        if photos.count <= 5
          keys = []
          0.upto(4) do |i|
            keys << Photo::FORMAT % (i % photos.count)
          end
        else
          size = photos.count / 5
          middles = [
            0..(size - 1),
            size..(size*2 - 1),
            (size*2)..(size*3 - 1),
            (size*3)..(size*4 - 1),
            (size*4)..(photos.count - 1)
          ].collect do |range|
            range.first + (range.last - range.first) / 2
          end
          keys = (0..4).to_a.collect{|i| Photo::FORMAT % (size / 2 + size * i)}
        end
        samples = photos.values_at(*keys)

        i = 1
        samples.each do |s|
          filename = self.samples.sub('.png', "#{i}.png");
          image = ImageSorcery.gm(config(:path) / s.uri(:resize))
          image.convert(filename, quality: self.config(:quality), thumbnail: "50^", gravity: "center", extent: '50x50')
          samples[i - 1] = filename
          i += 1
        end

        image = ImageSorcery.gm(self.samples)
        image.montage(samples,
                      background: '#000000FF', tile: '5x1', geometry: '50x50',
                      borderwidth: 1, bordercolor: '#000000FF', frame: '0x0+0+0')
        Optimize.file(self.samples)
      end
    end

    def sizes!(force = false)
      photos.each do |id, photo|
        photo.sizes!(force)
      end
      self.dump
    end

    def exif!(force = false)
      photos.each do |id, photo|
        photo.exif!(force)
      end
      self.dump
    end

    def times!(force = false)
      if @times.min.nil? or @times.max.nil? or force
        times = @photos.values.collect{|photo| photo.exif.time}.delete_if{|time| time == 0}
        @times = Times.new(times.min, times.max)
      end
      self.dump
    end

    def times
      @times
    end

    def zip!
      if config(:zip)
        system "cd #{config(:path) / @name}; zip -u -X -D -0 archive.zip #{@name}-*.jpg #{@name}-*.gif #{@name}-*.png"
      end
    end

    def zip
      'archive.zip'
    end

    def optimize!
      photos.each do |id, photo|
        photo.optimize!
      end
    end

    def clear!(keep_originals = false)
      [DUMP_FILE, "archive.zip", "samples.png"].each do |file|
        if File.exists? config(:path) / @name / file
          puts "Delete #{file}"
          File.unlink config(:path) / @name / file
        end
      end
      @@cache.delete @name
      @photos.each do |id, photo|
        photo.clear!(keep_originals)
      end
    end

  end
end
