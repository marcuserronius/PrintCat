# thumbnail.rb
#
# finds or creates an appropriate thumbnail
require 'shellwords'
require './lib/gcode'

def pp(v)
  p v
  v
end

def sx(s)
  Shellwords.escape(s)
end

def esc str
  p([str,str.gsub(/\?|\ |\#|\[|\]|\&/){|c|"%%%02x"%c.ord}])
  str.gsub(/\?|\ |\#|\[|\]|\&/){|c|"%%%02x"%c.ord}
end


# split a path into components
def fs(path)
  comp = []
  until path == "." || path == "/"
    path, e = *File.split(path)
    comp.unshift e
  end
  (path=="/")?['']+comp:comp
end

module Thumbnail
  GENERIC = "nothumb.png"

  TILES = {
    4=> <<-EOT,
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg version="1.1" 
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  width="1024" height="1024" viewBox="0 0 1024 1024">
  <g id="images">
    <image x="0"   y="0"   width="512" height="512" preserveAspectRatio="xMidYMid slice" id="image1"
      xlink:href="%s" />
    <image x="512" y="0"   width="512" height="512" preserveAspectRatio="xMidYMid slice" id="image2"
      xlink:href="%s" />
    <image x="0"   y="512" width="512" height="512" preserveAspectRatio="xMidYMid slice" id="image3"
      xlink:href="%s" />
    <image x="512" y="512" width="512" height="512" preserveAspectRatio="xMidYMid slice" id="image4"
      xlink:href="%s" />
  </g>
  <path id="frame" style="fill:none;stroke:black;stroke-width:16;"
    d="M 512,0 V 1024 M 0,512 h 1024" />
</svg>
    EOT
    3=> <<-EOT,
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg version="1.1" 
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  width="1024" height="1024" viewBox="0 0 1024 1024">
  <g id="images">
    <image x="0" y="512" width="1024" height="512" preserveAspectRatio="xMidYMid slice" id="image3"
      xlink:href="%s" />
    <image x="0"   y="0"   width="512" height="512" preserveAspectRatio="xMidYMid slice" id="image1"
      xlink:href="%s" />
    <image x="512" y="0"   width="512" height="512" preserveAspectRatio="xMidYMid slice" id="image2"
      xlink:href="%s" />
  </g>
  <path id="frame" style="fill:none;stroke:black;stroke-width:16;"
    d="M 512,0 V 512 M 0,512 h 1024" />
</svg>
    EOT
    2=> <<-EOT,
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg version="1.1" 
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  width="1024" height="1024" viewBox="0 0 1024 1024">
  <g id="images">
    <image x="0" y="512" width="1024" height="512" preserveAspectRatio="xMidYMid slice" id="image2"
      xlink:href="%s" />
    <image x="0"   y="0"   width="1024" height="512" preserveAspectRatio="xMidYMid slice" id="image1"
      xlink:href="%s" />
  </g>
  <path id="frame" style="fill:none;stroke:black;stroke-width:16;"
    d="M 0,512 h 1024" />
</svg>
    EOT
    1=> <<-EOT
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg version="1.1" 
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  width="1024" height="1024" viewBox="0 0 1024 1024">
  <g id="images">
    <image x="0" y="0" width="1024" height="1024" preserveAspectRatio="xMidYMid slice" id="image1"
      xlink:href="%s" />
  </g>
  <path id="frame" style="fill:none;stroke:black;stroke-width:32;"
    d="M 0,0 h 1024 v 1024 h -1024 v -1024" />
</svg>
    EOT
  }

  # gets the path to a thumbnail for this path, creating one if needed
  def self.get(item_path, gcode=nil);
    parent, item = *File.split(item_path)
    # valid extensions
    ext = ".{jpg,jpeg,png,gif,svg}"
    # are we dealing with a print file or a category/item
    if gcode # if it's a print file
      parts = gcode.name_parts
      tags = parts[:tags] || []
      # find the thumbnail, starting with most specific and moving back.
      # matches name, tags, and printer
      Dir[File.join(sx(parts[:parent]),sx(parts[:fullname])+ext)].first ||
        # matches name and tags
        Dir[File.join(sx(parts[:parent]),sx(parts[:longname])+ext)].first ||
        # matches name and any one tag
        pp(Dir[File.join(sx(parts[:parent]),sx(parts[:shortname])+"*"+ext)]).select{|fn|
          pp(fn[/\((.+?,\s?)*?(#{parts[:tags].join("|")})(,\s?.+?)*?\)/])
        }.first ||
        # matches just item name
        Dir[File.join(sx(parts[:parent]),sx(parts[:shortname])+ext)].first ||
        # doesn't exist, try to extract from gcode
        gcode.save_thumb ||
        # couldn't do it, use generic
        GENERIC
    else # if it's a group of print files
      # look for an existing thumbnail
      Dir[File.join(item_path,"thumb"+ext)].first ||
        # otherwise, make one
        make_thumb(item_path) ||
        # error, use generic
        GENERIC
    end
  end # self.get()

  # makes a thumbnail from SVG
  def self.make_thumb(item_path)
    udirs = (item_path == ".") ? -2 : fs(item_path).size
    cdirs = (item_path == ".") ? 0 : fs(item_path).size
    images = Dir[File.join(item_path,"**","*.{b,}gcode")].map{|gc|Thumbnail.get(gc,Gcode.new(gc))}.uniq
    s_imgs = images.shuffle.uniq{|p| fs(p)[0..udirs]}.map{|p|esc(File.join(fs(p)[cdirs..-1]))}
    if s_imgs.size >= 4
      File.write(File.join(item_path,"thumb.svg"), TILES[4] % s_imgs.sample(4))
      File.join(item_path,"thumb.svg")
    elsif s_imgs.size == 3
      File.write(File.join(item_path,"thumb.svg"), TILES[3] % s_imgs.sample(3))
      File.join(item_path,"thumb.svg")
    elsif s_imgs.size == 2
      File.write(File.join(item_path,"thumb.svg"), TILES[2] % s_imgs.sample(2))
      File.join(item_path,"thumb.svg")
    elsif s_imgs.size == 1
      File.write(File.join(item_path,"thumb.svg"), TILES[1] % s_imgs.sample(1))
      File.join(item_path,"thumb.svg")
    end

  end
end