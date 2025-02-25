#!/usr/bin/ruby
# create a page for each category and item. 

require 'ostruct'
require './lib/template'
require './lib/gcode'
require 'shellwords'
require 'erb'

class String
  def sqz() lines.map(&:strip).join; end
  # def tmpl(**kw)
  #   kw.keys.inject(self){|s,k|s.gsub("{#{k}}",kw[k])}
  # end
end

def esc str
  ERB::Util.url_encode str
end

### The HTML Templates
html = OpenStruct.new


# category, subcategory and item listings
html.catlist = Template.new(<<-HTML,squeeze:true)
    <div id="">
      {crumbs{<a class=breadcrumb href="{link}" title="{name}">{name}</a> }}
      <br><!-- end breadcrumbs -->
      <div class=subcatlist>
        {subcats{
        <a class="subcategory listing" id="{id}" href="{path}" title="{name}" data-tags="{tags}">
          <img src="{imagepath}">
          <span>{name}</span>
        </a>
        }}
      </div>
      <div class=itemlist>
        {items{
        <a class="item listing" id="{id}" href="{path}" title="{name}" data-tags="{tags}">
          <img src="{imagepath}">
          <span>{name}</span>
        </a>
        }}
      </div>
    </div>
HTML


# subitem listing
html.subitemlist = Template.new(<<-HTML,squeeze:true)
    <div class=subitemlist id="{itemid}-listing">
      {crumbs{<a class=breadcrumb href="{link}" title="{name}">{name}</a> }}
      <br><!-- end breadcrumbs -->
      {subitems{
      <a class="subitem listing" href="{path}" title="{name}" download="{filename}" data-tags="{tags}">
        <img src="{imagepath}">
        <span>{notes}</span>
      </a>
    }}
    </div>
HTML



### Load information and lists

# the missing image
nothumb = "nothumb.png"

# convert to id
id=->(str){str ? str.gsub(/[^[:alnum:]]/,"_"):"all"}
apath=->(path){path.split("/")}
spath=->(path){path.join("/")}
idx_for=->(dir){dir ? spath[[*apath[dir],"list.html"]]:"listall.html"}

# find all the print files and sort them
printfiles = Dir.glob('**/*.{b,}gcode').sort

# get all the listings
topcatpaths = []
subcatpaths = []
catpaths    = [] # in case it makes no sense to differentiate between top categories and subcats
cattags     = {}
itempaths   = []
printinfo   = {}
printfiles.each do |path|
  # split filename into parts
  *cats,item,file = path.split("/")
  # catpaths:
  cats.inject(nil){ |parent,child| (catpaths<<[parent,child].compact.join("/")).last }
  # itempaths:
  itempaths<<[*cats,item].join("/")
end
catpaths.uniq!
itempaths.uniq!
warn subcatpaths.inspect

# get and parse item information
printfiles.each do |path|
  i = printinfo[path] = OpenStruct.new
  i.gcode = Gcode.new(path)
  i.filename = apath[path].last
  i.fullname = i.filename[/^(.+?)_/,1]
  nameparts = i.fullname.match(/
    (?<longname>
      (?<shortname>.+?)\s*
      (?<tags>\(.+?\))?
    )\s*
    (?<printer>\[.+?\])?$
  /x)
  i.longname = nameparts[:longname]
  i.shortname = nameparts[:shortname]
  i.tags = (nameparts[:tags]||"(none)")[1...-1].split(/\s*,\s*/)
  i.printer = [i.gcode[:printer_model], i.gcode[:printer_variant]].compact.join(" ")
  i.etags = i.tags.map{|t| t.gsub(" ","_")}
  i.atags = i.etags+[i.printer.gsub(" ","_")]
  i.printtime = i.gcode[:"estimated printing time (normal mode)"]
end

def pp(val) p(val); val; end


### Output listings

# category and item listing
# "" => top level
# nil => list all
["",nil,*catpaths].each do |cp|
  File.open(idx_for[cp],'w') do |idx|
    idx.write html.catlist.fill(
      id: id[cp],
      crumbs: (apath[cp||" "].size).times.map do |n|
        { link: esc(idx_for[spath[apath[cp||" "].first(n)]]),
          name: n>0 ? apath[cp||" "][n-1] : "Top"
        }
      end,
      subcats: catpaths.select{|x|cp ? apath[x][0...-1]==apath[cp]:false}.map do |x|
        { id: x.gsub(/[^[:alnum:]]/,"_"),
          path: esc(idx_for[x]),
          name: x.split("/").last,
          tags: printfiles.map{|f|printinfo[f].atags if f.start_with? x}.flatten.compact.uniq.join(" "),
          imagepath: esc(Dir.glob(File.join(x,"thumb.{png,jpg,jpeg}")).first || nothumb)
        }
      end + (cp&.empty? ?
        [{id: "all",
          path: "listall.html",
          name: "All Items",
          tags: printfiles.map{|f|printinfo[f].atags}.flatten.compact.uniq.join(" "),
          imagepath: nothumb
        }]
        : []
      ),
      items: itempaths.select{|x|cp ? apath[x][0...-1]==apath[cp]:true}.map do |x|
        { id: x.gsub(/[^[:alnum:]]/,"_"),
          path: esc(idx_for[x]),
          name: x.split("/").last[/^(.+?)(?:\s\-\s[\d\()]+)?$/,1],
          tags: printfiles.map{|f|printinfo[f].atags if f.start_with? x}.flatten.compact.uniq.join(" "),
          imagepath: esc(Dir.glob(File.join(x,"thumb.{png,jpg,jpeg}")).first || nothumb)
        }
      end
    ) # template
  end
end

# subitem listing
itempaths.each do |ip|
  File.open(idx_for[ip],'w') do |idx|
    idx.write html.subitemlist.fill(
      id: id[ip],
      crumbs: (apath[ip].size).times.map do |n|
        { link: esc(idx_for[spath[apath[ip].first(n)]]),
          name: n>0 ? apath[ip][n-1] : "Top"
        }
      end,
      subitems: printfiles.select{|x|apath[x][0...-1]==apath[ip]}.map do |x|
        i = printinfo[x]
        # matches = apath[x].last.match(/
        #   ^(?<name>.+?)_
        #   ((?<nozzle>[\d\.]+)n_)? # optional nozzle size
        #   (?<layer_height>[\d\.]+mm)_
        #   (?<material>[^_]+)_
        #   (?<printer>[^_]+)_
        #   (?<time>[\dhm]+)\.gcode$
        # /x)
        # # remove tags and printer name from name
        # nameparts = matches[:name].match(/
        #   (?<fullname>
        #     (?<longname>
        #       (?<shortname>.+?)\s*
        #       (?<tags>\(.+?\))?
        #     )\s*
        #     (?<printer>\[.+?\])?
        #   )$
        # /x)

        if Dir.glob(ip+"/"+i.fullname+".{jpg,jpeg,png}").empty?
          File.write(ip+"/"+i.fullname+".png",i.gcode[:thumbnail])
        end
        { path: esc(x),
          name: i.shortname,
          tags: i.atags.join(" "),
          filename: i.filename,
          imagepath: esc(Dir.glob(ip+"/"+Shellwords.escape(i.fullname)+".{jpg,jpeg,png}").first || nothumb),
          notes:[
            i.shortname,
            "<i>Printer:</i> "+i.printer,
            "<i>Print time:</i> "+i.printtime,
            "<i>Tagged:</i> "+i.tags.join(", ")
          ].join("<br>")
        }
      end
    )
  end
end
