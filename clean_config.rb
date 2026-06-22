require 'yaml'
require 'YAML'
Value = YAML.load_file('/etc/openclash/config/bsc.yaml')
# Remove groups that have 'Provider_2AB7F1' in their 'use' field (injected by overwrite)
Value['proxy-groups'].reject! { |g| g['use']&.include?('Provider_2AB7F1') }
File.open('/etc/openclash/config/bsc.yaml','w') {|f| YAML.dump(Value, f)}
puts "Groups: #{Value['proxy-groups'].size}"
