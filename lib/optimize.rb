module Lib
module Optimize
  def self.file(filename)
    return if not File.exists? filename
    ext = File.extname(filename)[1..-1]
    send(ext, filename)
  end

  def self.jpg(filename)
    puts "Optimize JPG #{File.basename(filename)}"
    system "jpegtran -optimize -copy none -progressive -outfile '#{filename}' '#{filename}'"
  end

  def self.png(filename)
    puts "Optimize PNG #{File.basename(filename)}"
    system "pngcrush -q '#{filename}' '#{filename}.new'; mv '#{filename}.new' '#{filename}'"
  end

  def self.gif(filename, colors = 256)
    puts "Optimize GIF #{File.basename(filename)}"
    system "gifsicle -b --colors #{colors} '#{filename}'"
  end
end
end
