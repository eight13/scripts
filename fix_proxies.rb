require 'yaml'

cfg = YAML.load_file('/tmp/raw_sub.yaml')
proxies = cfg['proxies'] || []

# Convert inline JSON to standard YAML format
converted = proxies.map do |p|
  next p unless p.is_a?(String)
  begin
    # Parse JSON string from YAML
    parsed = eval(p)
    # Build standard YAML hash
    node = {}
    parsed.each { |k, v| node[k] = v }
    # Ensure reality-opts is a hash
    if node['reality-opts'].is_a?(String)
      node['reality-opts'] = eval(node['reality-opts'])
    end
    node
  rescue => e
    p  # Keep original
  end
end

cfg['proxies'] = converted
cfg.delete('proxy-providers')

# Remove use: from proxy-groups (points to missing providers)
if cfg['proxy-groups']
  cfg['proxy-groups'].each { |g| g.delete('use') if g.is_a?(Hash) }
end

File.open('/etc/openclash/config/bsc.yaml', 'w') { |f| YAML.dump(cfg, f) }
puts "Converted #{converted.size} proxies to standard YAML"
