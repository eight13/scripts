require 'yaml'
v = YAML.load_file('/tmp/raw_sub.yaml')
p = v['proxies'][0]
puts "Class: #{p.class}"
puts "Name: #{p['name']}" if p.respond_to?(:[])
puts "Type: #{p['type']}" if p.respond_to?(:[])
