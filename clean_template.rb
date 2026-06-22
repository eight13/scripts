require "yaml"
require "YAML"

# Names of region groups injected by overwrite (NOT from template)
injected = [
  "\u{1f1ed}\u{1f1f0} \u{9999}\u{6e2f}\u{8282}\u{70b9}",  # HK
  "\u{1f1ef}\u{1f1f5} \u{65e5}\u{672c}\u{8282}\u{70b9}",  # JP
  "\u{1f1f8}\u{1f1ec} \u{65b0}\u{52a0}\u{5761}\u{8282}\u{70b9}",  # SG
  "\u{1f1fa}\u{1f1f8} \u{7f8e}\u{56fd}\u{8282}\u{70b9}",  # US
  "\u{1f1fc}\u{1f1f8} \u{53f0}\u{6e7e}\u{8282}\u{70b9}",  # TW
  "\u{1f1f0}\u{1f1f7} \u{97e9}\u{56fd}\u{8282}\u{70b9}",  # KR
]

["/etc/openclash/bsc.yaml", "/etc/openclash/config/bsc.yaml"].each do |path|
  next unless File.exist?(path)
  begin
    v = YAML.load_file(path)
    before = v["proxy-groups"].size
    v["proxy-groups"].reject! { |g| injected.include?(g["name"]) }
    after = v["proxy-groups"].size
    File.open(path, "w") { |f| YAML.dump(v, f) }
    puts "#{File.basename(path)}: #{before} -> #{after} groups"
  rescue => e
    puts "#{path}: ERROR #{e.message}"
  end
end
