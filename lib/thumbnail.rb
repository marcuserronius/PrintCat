# thumbnail.rb
#
# finds or creates an appropriate thumbnail


class Thumbnail

  def self.get(item_path, gcode=nil);
    parent, item = *File.split(item_path)
    # valid extensions
    ext = %w[jpg jpeg png gif]
    # are we dealing with a print file or a category/item
    if item =~ /gcode$/
      # check for existing thumbnail with exact match
      if Dir[]