Gem::Specification.new do |s|
  s.name = 'bxtjson'
  s.version = '0.0.1'
  s.add_runtime_dependency "yajl-ruby", "~>1.2.1", ">= 1.2.0"
  s.add_runtime_dependency "multi_json", "~> 1.10", ">= 1.10.0"
  s.add_runtime_dependency "json_schema", "~>0.5", ">=0.5.0"
  s.date = '2015-03-26'
  s.summary = 'Map between json schema'
  s.description = 'initialize empty hash from schema, map from hash to schema, return a lazy enumerable'
  s.authors = ['Jacob Kroeze']
  s.email = 'jlkroeze@gmail.com'
  s.files = ['lib/bxtjson.rb']
  s.homepage = 'https://github.com/jacob-kroeze/bxtjson'
  s.license = 'MIT'
end
