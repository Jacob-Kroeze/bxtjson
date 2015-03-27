# input stream style (new-line separated) json objects from 
# naive BASIC script in FSMS. FSMS is a multi-value store
# on the IBM u2 platform
# main method map_onto_skeleton_of_schema
# JSON -> JSON
require 'multi_json'
require 'json_schema'
module Bxtjson
  ## dependencies
  ## gem: json_schema
  ## gem: multi_json
  ## gem: oj  || other json library
  ## You implement a model in Sequel or ActiveRecord if you want.
  ############################################################
  # Constants                                               #
  # KEY_CLEANER = ->(str) {str.gsub(/\W+/, " ").lstrip        #
  #     .gsub(" ", "_")                                       #
  #     .gsub(/PPPO_|PPCO_/, "")                              #
  #     .downcase                                             #
  # }                                                 #
  # JSON_FILENAME = "../../../fsms-tmp/PP_PROPOSAL_2015.JSON" #
  # SCHEMA_FILENAME = "./docs/schema.json"                    #
  # SKELETON_DATA = -> (){ skeleton()}
  # AUTHORIZING_POINTER '#/departments/primary_dept'
  ######################################                    #
  ############################################################
  # initialize an empty hashmap given a json schema
  # Arguments:
  # * schema_data: Hash from parse json-schema
  # * entity: String,  section of schema to initialize. 
  #   * if nil, use full schema
  # Hash -> Hash
  def self.skeleton(schema_data:,
                    entity: nil)
    schema = JsonSchema.parse!(schema_data)
    schema.expand_references!
    p "****"
    if entity.nil?
      entity_schema = schema
    else 
      entity_schema = schema.properties[entity]
    end
    return _skeleton(entity_schema, acc: {})
  end
  # process a file of jsonl (linefeed) and clean keys with proc
  # File -> [{}]
  def self.text_to_lazy_json(json_filename:,
                             clean_proc:)
    File.foreach(json_filename)
      .lazy
      .map do |line|
      _key_cleaner(data: MultiJson.load(line))
    end
  end
  # given JsonSchema and a filename, parse file and map contents
  # onto schema.
  # Mapping of contents will search for the first key in the source,
  # that matched the schema (recursively). So, the source should be
  # flat for clarity, and the schema can be nested.
  # This method also validates using JsonSchema
  # TODO: design interface from csv to json that fits these
  # principles.
  # Paramaters:
  # * json_filename: JSON_FILENAME
  # * schema_filename: SCHEMA_FILENAME
  # * clean_proc: KEY_CLEANER
  # * model: 'String' that responds to create
  # * authorizing_pointer: '#departments/primary_dept'
  # File -> Hash[uuid, Boolean]
  def self.map_onto_skeleton_of_schema(json_filename:,
                                       schema_filename:,
                                       clean_proc: ->(str){str},
                                       model: nil,
                                       authorizing_pointer:)
    skeleton = Bxtjson.skeleton(schema_data: MultiJson.load(File.read(schema_filename)))
    if model
      model = model.to_s.capitalize.constantize

      text_to_lazy_json(filename: json_filename, clean_proc: clean_proc )
        .map {|data| 
        data = fillin(source_hash: _map_onto_skeleton_of_schema( data, 
                                                                 clean_proc: clean_proc,
                                                                 skeleton: skeleton ),
                      skeleton: skeleton) 
        result = model.create(data: data)
      }
    else
      out = []
      text_to_lazy_json(json_filename: json_filename, clean_proc: clean_proc )
        .map {|data| out << fillin(source_hash: _map_onto_skeleton_of_schema( data, 
                                                                              clean_proc: clean_proc,
                                                                              skeleton: skeleton ),
                                   skeleton: skeleton)
      }
    end
  end
  # Recursively remove falsey values from hash
  # Falsey values are those that return true from respond_to(:empty?)
  # or :nil?
  # Hash -> Hash
  def self.compact_hash(hash)
    p = proc do |_, v|
      v.delete_if(&p) if v.respond_to? :delete_if
      v.respond_to?(:empty?) && v.empty? || v.nil?
    end
    hash.delete_if(&p)
  end
  private
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
  # (String, Hash) -> Hash
  def self.lookup(key, source_hash)
    source_hash[key]
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
    # pad the array if current array length is not eq max length of arrays
    sorted = matrix.sort_by(&:length)
    max = sorted.last.length
    sorted.map {|item|
      item.fill( [sorted.first.first[0], nil], (item.length)..(max - 1) )
    }
    sorted

    # transpose keeping a slot if empty (like a speadsheet)
    head, *tail = sorted
    (head.zip *tail).map(&:to_h)

  end

  # given a source_hash, find the first key from a skeleton hash
  # and insert value. Depends on flat source hash
  # (Hash, Hash) -> Hash
  # a bit lost here
  def self.fillin(source_hash:, skeleton:, acc: {})
    case
    when skeleton.kind_of?( Hash )
      acc = Hash[skeleton.map do |key, value|
                   # recurse on skeleton levels
                   [key,( lookup(key, source_hash) or fillin(source_hash: source_hash, skeleton: value) ) ]
                 end
                ]
    when skeleton.kind_of?( Array )
      # when an array, multi-value database IBM U2 provide keys with
      # an array (eg Key: [1,2,3]) but we want obj: [{key:1}, {key: 2}]
      #        acc = skeleton.map do |item|
      acc = expand_array_to_objects( array: skeleton,
                                     source_hash: source_hash)
    when skeleton.nil?
      byebug
      acc
    else
      acc = nil
    end
    return acc
  end
  # loop through hash, cleaning keys, and mapping to new schema
  # Hash -> Hash
  def self._map_onto_skeleton_of_schema(json_data,
                                        acc: {},
                                        clean_proc:,
                                        skeleton:)

    case 
    when json_data.kind_of?(Hash)
      acc = Hash[json_data.map do |key, value|
                   [clean_proc.call(key),
                    _map_onto_skeleton_of_schema(value,
                                                 acc: acc,
                                                 clean_proc: clean_proc,
                                                 skeleton: skeleton)
                   ]
                 end
                ]
    when json_data.kind_of?(Array)
      acc =  json_data.map do |item|
        _map_onto_skeleton_of_schema(item, clean_proc: clean_proc, skeleton: skeleton)
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
end
