# input stream style (new-line separated) json objects
# main method map_onto_skeleton_of_schema
# JSON -> JSON

require 'yajl'
require 'multi_json'
require 'json_schema'
  # == dependencies
  # * gem: json_schema
  # * gem: multi_json
  # * JSON standard library or other (e.g. oj) json parsers
  # * You implement a model in Sequel or ActiveRecord if you want.
  # == Constants (examples)
  #   cleaner_proc = ->(str) {str.gsub(/\W+/, " ").lstrip
  #       .gsub(" ", "_")
  #       .gsub(/PPPO_|PPCO_/, "")
  #       .downcase
  #   }
  #   json_filename = "../../../fsms-tmp/PP_PROPOSAL_2015.JSON"
  #   schema_filename = "./docs/schema.json"
  #   authorizinng_pointer '#/departments/primary_dept'

module Bxtjson
  # Initialize an empty hashmap given a json-schema[http://json-schema.org]
  #
  # @param [Hash] schema_data the data from json-schema
  # @param [String, nil] entity the resource name to enfocus
  # @return [Hash] the an empty "initialized" json-schema
  def self.skeleton(schema_data:,
                    entity: nil)
    schema = JsonSchema.parse!(schema_data)
    schema.expand_references!
    if entity.nil?
      entity_schema = schema
    else 
      entity_schema = schema.properties[entity]
    end
    return _skeleton(entity_schema, acc: {})
  end
  # process a file of jsonl (linefeed) and clean keys with proc
  #
  # @param [String] json_filename source of json objects in jsonl[https://github.com/stephenplusplus/jsonl] format
  # @param [Proc] a function to clean up keys
  # @return [Hash] hash of arrays `[{  }]`
  def self.text_to_lazy_json(json_filename:,
                             clean_proc:)
    File.foreach(json_filename)
      .lazy
      .map do |line|
      _key_cleaner(data: MultiJson.load(line), clean_proc: clean_proc)
    end
  end
  # Parse json-schema file and map contents of json file into
  # initialized schema
  #
  # Mapping of contents will search for the first key in the source,
  # that match the schema (recursively). So, the source should be
  # flat for clarity, and the schema can be nested.
  #
  # If it cannot find a key, it will look for "top/next/final" path
  # key in the source data.
  # 
  # For example, in the skeleton
  #  {key: {nest: "this"} }
  # Will be filled with "muscle" if the source has a ket
  #  {"key/nest": "data muscle"}
  #
  # TODO: design interface from csv to json that fits these
  # principles.
  # 
  # @param [String] json_filename filename for jsonl source
  # @param [String] schema_filename filename for json-schema
  # @param [Proc] clean_proc a function to clean up keys
  # @param [String, #create] model the name of a model to call :create on
  # @param [String] authorizing_pointer json-pointer[https://tools.ietf.org/html/rfc6901] that fills in the key "authorized_by"
  def self.muscle(json_filename:,
                  schema_filename:,
                  clean_proc: ->(str){str},
                  model: nil,
                  schema_entity: nil,
                  authorizing_pointer:,
                  data_attr: :data)     
    skeleton = Bxtjson.skeleton(schema_data: MultiJson.load(File.read(schema_filename)),
                                entity: schema_entity)
    if model
      model = constantize(model.to_s.capitalize)

      text_to_lazy_json(json_filename: json_filename, clean_proc: clean_proc )
        .map {|data| 
        data = fillin(source_hash: _map_onto_skeleton_of_schema( data) , 
                      skeleton: skeleton) 
        result = model.create( data_attr => data)
      }
    else
      out = []
      text_to_lazy_json(json_filename: json_filename, clean_proc: clean_proc )
        .map {|data| out << fillin(source_hash: _map_onto_skeleton_of_schema( data),
                                   skeleton: skeleton)
      }
    end
  end
  # Muscle fillin with just one json object
  def self.muscle_one(line, skeleton, clean_proc:)
        Bxtjson.fillin( source_hash: Bxtjson._map_onto_skeleton_of_schema(
                                                              Bxtjson._key_cleaner(data: MultiJson.load(line), 
                                                                                   clean_proc: clean_proc)
                                                                          ),
                        skeleton: skeleton)
  end

  # Recursively remove falsey values from hash
  # Falsey values are those that return true from respond_to(:empty?)
  # or :nil?
  # @param [Hash] hash
  # @return [Hash]
  def self.compact_hash!(hash)
    p = proc do |_, v|
      v.delete_if(&p) if v.respond_to? :delete_if
      v.respond_to?(:empty?) && v.empty? || v.nil? ||
        v.respond_to?(:any?) && v.first.empty?
    end
    hash.delete_if(&p)
  end
  def self.compact_hash_greedy!(hash)
    p = proc do |_, v|
      if v.respond_to?(:delete_if)
        v.delete_if(&p)
      end
      v.respond_to?(:empty?) && v.empty? || v.nil?
    end
    hash.delete_if(&p)
  end
  # Given or array, remove any nil or empty values. If it's a hash,
  # remove key as well.
  # @param [Hash] h
  # @return [hash]

  def self.compact_hash_greedy(h)
    #select with prepend "!" may be faster.
    h.map{|k,v|
      case v
      when Hash
        [k, compact_hash_greedy(v)] if clean_nil_or_empty(v)
      when Array
        [k, v.map{|item| compact_hash_greedy(item) if clean_nil_or_empty(item)
         }.compact.reject(&:empty?)] if clean_nil_or_empty(v)
      else
        [k,v] if clean_nil_or_empty(v)
      end
    }.compact.reject(&:empty?).to_h
  end
  def self.compact_values!(hash)
    Hash[hash.map do |key, value|
           [key,
            if value.is_a?(Array)
              value.map {|item| Bxtjson.compact_hash!(item) }
            elsif value.respond_to?( :delete_if)
              Bxtjson.compact_hash!(value)
            else
              value
            end
           ]
         end
        ]
  end
  private
  def self.clean_nil_or_empty(e)
    if e.nil? || e.respond_to?(:empty) && e.empty?
      nil
    else
      e
    end
  end

  # Creates a skeleton for object and array from a Json Schema
  # Boolean, String, Number, Integer, Null are given a nil value to start.
  # Hash -> Hash
  def self._skeleton(json_schema, acc={})  
  case json_schema.type
    when ["object"]
      acc = Hash[json_schema.properties.map do |key, value|
                   [key,  _skeleton(value, acc)]
                 end
                ]
    when ["array"] # at this point the key is already in the Hash,
      # just need to return an array with one hash
      acc = [
             json_schema.items.properties.map { |key, value|
               [key, _skeleton(value, acc)]
             }.to_h
            ]
    else
      return nil
    end
    return acc
  end
  # given a key, return value of lookup recursively
  # if that lookup fails, try by path
  # (String, Hash) -> Hash
  def self.lookup(key, source_hash, path=[])
    source_hash.fetch(key, nil) || source_hash.fetch(path.join("/"), nil)
  end

  # Take an array of hashes with a hash that contains values to
  # insert. Expand the arrays into objects
  # (e.g. key: [1,2,3] -> [{key: 1}, {key: 2}, {key: 3})
  # (Array, Hash) -> {[]}
  def self.expand_array_to_objects(array:, source_hash: )
    matrix = array.first.map do |key, _|
      # if a plain string put into array. Flatten all others.
      [lookup(key, source_hash)].flatten.map {|value|
        # zipmap behavior here so that if one array is shorter
        # the result is nill when mapped against longer array
        # ["a"].zip  ["a", "b"] | reverse # => {"a":"a", "b":nil]
        #          h = Hash[ [[value].zip( [key]).map(&:reverse).flatten ] ]
        [value].zip( [key]).map(&:reverse).flatten

      }
    end
    # pad the array if current array length is not eq max length of
    # arrays. Pad is the first element. This is how some reports treat
    # repeating values (a la sql reporting)
    sorted = matrix.sort_by(&:length)
    max = sorted.last.length
    sorted.map {|item| # padding done here. Second element in array,
      # below, could be nil. Todo: paramaterize that as option
      item.fill( [sorted.first.first[0], sorted.first.first[1] ], (item.length)..(max - 1) )
    }
    sorted

    # transpose keeping a slot if empty (like a speadsheet)
    head, *tail = sorted
    (head.zip *tail).map(&:to_h)

  end

  # given a source_hash, find the first key from a skeleton hash
  # and insert value. Depends on flat source hash
  # remember the path during lookup with skeleton
  # (Hash, Hash) -> Hash
  # a bit lost here
  def self.fillin(source_hash:, skeleton:, acc: {}, path: [])
    case
    when skeleton.kind_of?( Hash )
      acc = Hash[skeleton.map do |key, value|
                   path.push key # save hash depth to stack-like []
                   # recurse on skeleton levels
                   [
                    [ path.last, (fillin(source_hash: source_hash,
                                         skeleton: nil,
                                         acc: lookup(key, source_hash, path),
                                         path: path) or
                                  fillin(source_hash: source_hash,
                                         skeleton: value,
                                         path: path))
                    ],
                    path.pop # pop the path at end of recursion,
                    #      and drop from returned array
                   ][0]
                 end
                ]
    when (skeleton.kind_of?( Array) and skeleton.first.empty?)
      # when an array with no inner objects/hashmaps
      acc = lookup(path.last, source_hash)
    when skeleton.kind_of?( Array )
      # when an array (eg Key: [1,2,3]) but we want obj: [{key:1}, {key: 2}]
      acc = expand_array_to_objects( array: skeleton,
                                     source_hash: source_hash)
    when skeleton.nil? # the acc value should be a string, so join if possible
      if acc.respond_to?(:join)
        acc = acc.join
      elsif acc.respond_to?(:empty?)
        acc = acc.empty? ? nil : acc
      else
        acc = acc
      end
    else
      acc = nil
    end
    return acc
  end
  # loop through hash, cleaning keys
  # of note: if a "key/key" pointer where key == key then only the 
  # value of the nested key will be returned. Use a naming convention
  # of "keys/key" or "unique/uniqueNest"
  # Hash -> Hash
  def self._map_onto_skeleton_of_schema(json_data,
                                        acc: {} )
    case 
    when json_data.kind_of?(Hash)
      acc = Hash[json_data.map do |key, value|
                   [key,
                    _map_onto_skeleton_of_schema(value,
                                                 acc: acc)

                   ]
                 end
                ]
    when json_data.kind_of?(Array)
      acc =  json_data.map do |item|
        _map_onto_skeleton_of_schema(item)
      end
    else
      acc = json_data
    end
  end
  def self._key_cleaner(data:, clean_proc: ->(str){str}, acc: {})
    case
    when data.kind_of?(Hash)
      acc = Hash[ data.map do |key, value|
                    [ clean_proc.call(key), _key_cleaner(data: value) ]
                  end
                ]
    else
      acc = data
    end
    acc
  end
# File activesupport/lib/active_support/inflector.rb, line 278
  def self.constantize(camel_cased_word)
    unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ camel_cased_word
      raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!"
    end

    Object.module_eval("::#{$1}", __FILE__, __LINE__)
  end
end

