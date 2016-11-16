module Lib
  class Album

    @@cache = {}
    @@timestamps = {}

    DUMP_FILE = "album.msh"

    def self.load(name)
      filename = Config.default(:path) / name / DUMP_FILE
      if not File.exists? filename
        @@cache[name] = Album.new(name)
        @@timestamps[name] = 0
      else
        ts = File.mtime(filename).to_i
        if not @@cache.key? name or @@timestamps[name] != ts
          @@timestamps[name] = ts
          begin
            @@cache[name] = Marshal.load(File.read(filename))
          rescue
            @@cache[name] = Album.new(name)
          end
        end
      end
      @@cache[name]
    end

    def initialize(name)
      @name = File.basename(name)
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

    def timestamp
      if @timestamp.nil?
        if photos.keys.first.nil?
          return 0
        else
          @timestamp = photos[photos.keys.first].timestamp
          self.dump
        end
      end
      @timestamp
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

      count = 8

      if not File.exists? self.samples or force
        if photos.count <= count
          keys = []
          0.upto(count - 1) do |i|
            keys << Photo::FORMAT % (i % photos.count)
          end
        else
          keys = photos.keys.sample(count)
        end
        samples = photos.values_at(*keys)

        i = 1

        size = 200

        samples.each do |s|
          filename = self.samples.sub('.png', "#{i}.png");
          image = ImageSorcery.gm(config(:path) / s.uri(:thumb))
          image.convert(filename, quality: self.config(:quality), thumbnail: "#{size}^", gravity: "center", extent: "#{size}x#{size}")
          samples[i - 1] = filename
          i += 1
        end

        image = ImageSorcery.gm(self.samples)
        image.montage(samples,
                      background: '#000000FF', tile: '4x2', geometry: "#{size}x#{size}+0+0",
                      borderwidth: 1, bordercolor: '#000000FF')
        Optimize.file(self.samples)

        samples.each do |sample|
          File.unlink sample
        end
      end
    end

    def sizes!(force = false)
      photos.each do |id, photo|
        photo.sizes!(force)
      end
      self.dump
    end

    def zip!
      if config(:zip)
        system "cd #{config(:path) / @name}; zip -u -X -D -0 archive.zip #{@name}-*.jpg #{@name}-*.gif #{@name}-*.png"
      end
    end

    def zip
      'archive.zip'
    end

    def optimize!(force = false)
      photos.each do |id, photo|
        photo.optimize!(force)
      end
      self.dump
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
