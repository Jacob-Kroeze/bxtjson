require 'easy_diff'
require 'facets/enumerable/graph'
module Bxtjson
  module Diff
    def self.get_diff(old, new)
      old.easy_diff(new)
    end
    def self.html_out(old, new)
      removed, added = get_diff(old, new)
#      removed.graph {|key,value| [k, "<strike> #{value}</strike"]}
    end
  end
end
