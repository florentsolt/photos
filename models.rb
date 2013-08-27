require 'uri'
require 'json'

# / helpers
class String; def /(path); File.join(self, path.to_s); end; end
class Symbol; def /(path); File.join(self.to_s, path.to_s); end; end

module Model
  CONFIG = YAML.load_file(__dir__ / 'config.yml')
end

['stream', 'set', 'photo'].each do |model|
    require File.join(__dir__, 'models', model)
end

require File.join(__dir__, 'db')


