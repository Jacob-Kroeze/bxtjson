require "json"
require "yaml"
require_relative "../lib/bxtjson"

module Commands
  class Bxtjson
    attr_accessor :errors
    attr_access :messages
    def initialize
      @detect = false
      @errors = []
      @messages = []
    end

    def run(argv)
      return false if !(schema_file = argv.shift)
      return false if !(schema = parse(schema_file))
      return false if argv.count < 1

      argv.each do |data_file|
        if !(data = read_file(data_file))
          return false
        end

        # validate json schema
        
    end
  end
end
