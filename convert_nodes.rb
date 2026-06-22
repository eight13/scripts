require 'yaml'
require 'json'

cfg = YAML.load_file('/etc/openclash/config/bsc.yaml')

# Extract inline JSON proxies
proxies = cfg['proxies'] || []
proxies.each do |p|
  next unless p.is_a?(String)
  begin
    parsed = JSON.parse(p)
    proxies[proxies.index(p)] = parsed
  rescue
  end
end

# Replace inline JSON strings with parsed hashes
cfg['proxies'] = proxies

# Remove proxy-providers section entirely (causes pull errors)
cfg.delete('proxy-providers')
# Also clean stale references in groups
if cfg['proxy-groups']
  cfg['proxy-groups'].each do |g|
    g.delete('use') # remove provider references
  end
end

File.open('/etc/openclash/config/bsc.yaml', 'w') { |f| YAML.dump(cfg, f) }
puts "OK: #{proxies.size} proxies"
