# gcode.rb
#
# Parses PrusaSlicer gcode files to get some basic info from them


class Gcode
	attr_accessor :path, :values, :name_parts
	private :path=, :values=, :values, :name_parts=

  def self.new(path)
    self::CACHE ||= {}
    self::CACHE[path] ||
      (self::CACHE[path] = super)
  end


	def initialize(path)
		self.path = path
    parse_name_parts
	end

	def inspect
		"#{self.class}(#{path})"
	end

  # parse gcode filename
  private def parse_name_parts
    self.name_parts = {}
    i = name_parts
    i[:parent], i[:filename] = *File.split(path)
    i[:fullname] = i[:filename][/^(.+?)_/,1]
    matches = i[:fullname].match(/
      (?<longname>
        (?<shortname>.+?)\s*
        (?<tags>\(.+?\))?
      )\s*
      (?<printer>\[.+?\])?$
    /x)
    i[:longname] = matches[:longname]
    i[:shortname] = matches[:shortname]
    i[:tags] = (matches[:tags]||"(none)")[1...-1].split(/\s*,\s*/)
  end

	# grab the first value for the given key (should be the only one)
	def [](key)
		if values.nil?
			self.values = {}
			fetch_values
		end
		values[key.to_s]
	end

	# save the gcode thumbnail under the "fullname"; returns nil if unsuccessful
	def save_thumb
		if self[:thumbnail]
      fn = File.join(name_parts[:parent], name_parts[:fullname]+".png")
      File.write(fn,self[:thumbnail])
      fn
    else
      nil
    end
  end

	# fetch all the keys
	private def fetch_values
		File.open(path,'r') do |g|
			until g.eof?
				line = g.readline

				# thumbnail needs special parsing
				if line =~ /thumbnail begin/
					data = "" # container for base64 data
					loop do
						line = g.readline
						if line =~ /thumbnail end/ # no more data
							break
						else
							data << line[%r{[a-zA-Z0-9/+=]+}] # get base64 part of line
						end
					end
					require 'base64'
					values['thumbnail'] = Base64.decode64(data)
				end

				# if there's a key/value pair, extract it
				if line =~ /^; (.+) = ([^\n]+)$/
					values[$1] = $2 # captured key/value from prev line
				end

			end # until g.eof?
		end # close file

	end
end