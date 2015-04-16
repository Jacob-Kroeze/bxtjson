# bxtjson
Map json from source to fit schema structure

# The Gist

Sometimes, you have a B.erry X.tra special T.-rex json-schema(.org), but she doesn't even have a skeleton.

    Bxtjson.skeleton(JsonSchemaHashMap)
    #=> {
          your: nil,
          skeleton: [],
          ready: {
            for: nil,
            data: nil
            }
        }
        
Othertimes your T-rex json-schema is lost in a Pre-historic ForestSchema. For more details on that forest, 
_Read up on the very useful [json_schema](https://github.com/brandur/json_schema) library._

    Bxtjson.skeleton(ForestSchema, entity: 't-rex')
    #> {the: nil, skeleton: [], 'just-for-trex' => nil}
    
Then, bring him to life with

    Bxtjson.muscle(json_filename: 'path/to/trex-data.jsonl', schema_filename: 'path/to/trex-schema.json')
    #=> {
          your: 'muscled',
          skeleton: [:super, :strong, :now],
          ready: {
            for: 'action',
            data: 'forest of beasts'
            }
        } # this is lazy, so use `take(10).force` or the like.
That's it. Super short source code with docs, so read-up. You can also save out the data to a model (ActiveRecord; Sequel) that responds to method 'create'

I'm going for functional style code, so you can also use the "methods" in Bxtjson for your own purposes.
Very open to contribution, comment, and write me some tests.
