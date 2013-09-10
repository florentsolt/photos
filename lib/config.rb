require 'singleton'

module Lib
class Config
  include Singleton

  def self.method_missing(name, *args, &block)
    self.instance.send(name, *args)
  end

  def initialize
    @default_file = __dir__ / '..' / 'config.yml'
    if not File.exists? @default_file
      throw "Config file does not exits, start from the -dist file"
    end
    @default = YAML.load File.read(@default_file)
  end

  def default(name, key = nil)
    if key.nil?
      value = @default[name.to_s]
    else
      value = @default[name.to_s][key.to_s]
    end

    if name.to_s == 'path' and value[0] != '/'
      __dir__ / '..' / value
    else
      value
    end
  end

  def flickr=(flickr)
    @default['flickr']['access_token'] = flickr.access_token
    @default['flickr']['access_secret'] = flickr.access_secret

    File.open(@default_file, 'w') do |fd|
      fd.puts @default.to_yaml
    end
  end

  def get(album, name)
    if @config.nil? or @album != album
      @album = album

      # load and merge
      @config = @default.merge YAML.load(File.read(default('path') / @album.name / 'config.yml'))

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

end
end
