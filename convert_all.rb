require 'yaml'
v = YAML.load_file('/tmp/raw_sub.yaml')
v.delete('proxy-providers')
if v['proxy-groups']
  v['proxy-groups'].each { |g| g.delete('use') if g.is_a?(Hash) }
end
File.open('/etc/openclash/config/bsc.yaml', 'w') { |f| YAML.dump(v, f) }
File.open('/etc/openclash/bsc.yaml', 'w') { |f| YAML.dump(v, f) }
puts "Proxies: #{v['proxies'].size}, Groups: #{v['proxy-groups'].size}"
