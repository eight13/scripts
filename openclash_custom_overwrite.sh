#!/bin/sh
. /usr/share/openclash/ruby.sh
. /usr/share/openclash/log.sh
. /lib/functions.sh

# This script is called by /etc/init.d/openclash
# Add your custom overwrite scripts here, they will be take effict after the OpenClash own srcipts

LOG_TIP "Start Running Custom Overwrite Scripts..."
LOGTIME=$(echo $(date "+%Y-%m-%d %H:%M:%S"))
LOG_FILE="/tmp/openclash.log"
#Config Path
CONFIG_FILE="$1"

    #Simple Demo:
    #Key Overwrite Demo
    #1--config path
    #2--key name
    #3--value
    #ruby_edit "$CONFIG_FILE" "['redir-port']" "7892"
    #ruby_edit "$CONFIG_FILE" "['secret']" "123456"
    #ruby_edit "$CONFIG_FILE" "['dns']['enable']" "true"
    #ruby_edit "$CONFIG_FILE" "['dns']['proxy-server-nameserver']" "['https://doh.pub/dns-query','https://223.5.5.5:443/dns-query']"

    #Hash Overwrite Demo
    #1--config path
    #2--key name
    #3--hash type value
    #ruby_edit "$CONFIG_FILE" "['dns']['nameserver-policy']" "{'+.msftconnecttest.com'=>'114.114.114.114', '+.msftncsi.com'=>'114.114.114.114', 'geosite:gfw'=>['https://dns.cloudflare.com/dns-query', 'https://dns.google/dns-query#ecs=1.1.1.1/24&ecs-override=true'], 'geosite:cn'=>['114.114.114.114'], 'geosite:geolocation-!cn'=>['https://dns.cloudflare.com/dns-query', 'https://dns.google/dns-query#ecs=1.1.1.1/24&ecs-override=true']}"
    #ruby_edit "$CONFIG_FILE" "['sniffer']" "{'enable'=>true, 'parse-pure-ip'=>true, 'force-domain'=>['+.netflix.com', '+.nflxvideo.net', '+.amazonaws.com', '+.media.dssott.com'], 'skip-domain'=>['+.apple.com', 'Mijia Cloud', 'dlg.io.mi.com', '+.oray.com', '+.sunlogin.net'], 'sniff'=>{'TLS'=>nil, 'HTTP'=>{'ports'=>[80, '8080-8880'], 'override-destination'=>true}}}"

    #Map Edit Demo
    #1--config path
    #2--map name
    #3--key name
    #4--sub key name
    #5--value
    #ruby_map_edit "$CONFIG_FILE" "['proxy-providers']" "HK" "['url']" "http://test.com"

    #Hash Merge Demo
    #1--config path
    #2--key name
    #3--hash
    #ruby_merge_hash "$CONFIG_FILE" "['proxy-providers']" "'TW'=>{'type'=>'http', 'path'=>'./proxy_provider/TW.yaml', 'url'=>'https://gist.githubusercontent.com/raw/tw_clash', 'interval'=>3600, 'health-check'=>{'enable'=>true, 'url'=>'http://cp.cloudflare.com/generate_204', 'interval'=>300}}"
    #ruby_merge_hash "$CONFIG_FILE" "['rule-providers']" "'Reject'=>{'type'=>'http', 'behavior'=>'classical', 'url'=>'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/refs/heads/master/Clash/Apple.list', 'path'=>'./rule_provider/Apple.list', 'interval'=>86400}"

    #Array Edit Demo
    #1--config path
    #2--key name
    #3--match key name
    #4--match key value
    #5--target key name
    #6--target key value
    #ruby_arr_edit "$CONFIG_FILE" "['proxy-groups']" "['name']" "Proxy" "['type']" "smart"
    #ruby_arr_edit "$CONFIG_FILE" "['dns']['nameserver']" "" "114.114.114.114" "" "119.29.29.29"

    #Array Insert Value Demo:
    #1--config path
    #2--key name
    #3--position(start from 0, end with -1)
    #4--value
    #ruby_arr_insert "$CONFIG_FILE" "['dns']['nameserver']" "0" "114.114.114.114"

    #Array Insert Hash Demo:
    #1--config path
    #2--key name
    #3--position(start from 0, end with -1)
    #4--hash
    #ruby_arr_insert_hash "$CONFIG_FILE" "['proxy-groups']" "0" "{'name'=>'Disney', 'type'=>'select', 'disable-udp'=>false, 'use'=>['TW', 'SG', 'HK']}"
    #ruby_arr_insert_hash "$CONFIG_FILE" "['proxies']" "0" "{'name'=>'HKG 01', 'type'=>'ss', 'server'=>'cc.hd.abc', 'port'=>'12345', 'cipher'=>'aes-128-gcm', 'password'=>'123456', 'udp'=>true, 'plugin'=>'obfs', 'plugin-opts'=>{'mode'=>'http', 'host'=>'microsoft.com'}}"
    #ruby_arr_insert_hash "$CONFIG_FILE" "['listeners']" "0" "{'name'=>'name', 'type'=>'shadowsocks', 'port'=>'12345', 'listen'=>'0.0.0.0', 'rule'=>'sub-rule-1', 'proxy'=>'proxy'}"

    #Array Insert Other Array Demo:
    #1--config path
    #2--key name
    #3--position(start from 0, end with -1)
    #4--array
    #ruby_arr_insert_arr "$CONFIG_FILE" "['dns']['proxy-server-nameserver']" "0" "['https://doh.pub/dns-query','https://223.5.5.5:443/dns-query']"

    #Array Insert From Yaml File Demo:
    #1--config path
    #2--key name
    #3--position(start from 0, end with -1)
    #4--value file path
    #5--value key name in #4 file
    #ruby_arr_add_file "$CONFIG_FILE" "['dns']['fallback-filter']['ipcidr']" "0" "/etc/openclash/custom/openclash_custom_fallback_filter.yaml" "['fallback-filter']['ipcidr']"

    #Delete Array Value Demo:
    #1--config path
    #2--key name
    #3--value
    #ruby_delete "$CONFIG_FILE" "['dns']['nameserver']" "114.114.114.114"

    #Delete Key Demo:
    #1--config path
    #2--key name
    #3--key name
    #ruby_delete "$CONFIG_FILE" "['dns']" "nameserver"
    #ruby_delete "$CONFIG_FILE" "" "dns"

    #Ruby Script Demo:
    #ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
    #   begin
    #      Value = YAML.load_file('$CONFIG_FILE');
    #   rescue Exception => e
    #      puts '${LOGTIME} [error] Load File Failed,【' + e.message + '】';
    #   end;

        #General
    #   begin
    #   Thread.new{
    #      Value['redir-port']=7892;
    #      Value['tproxy-port']=7895;
    #      Value['port']=7890;
    #      Value['socks-port']=7891;
    #      Value['mixed-port']=7893;
    #   }.join;

    #   rescue Exception => e
    #      puts '${LOGTIME} [error] Set General Failed,【' + e.message + '】';
    #   ensure
    #      File.open('$CONFIG_FILE','w') {|f| YAML.dump(Value, f)};
    #   end" 2>/dev/null >> $LOG_FILE

# ========== 清理损坏的订阅 Provider ==========
LOG_OUT "Cleaning broken proxy providers..."
ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   begin
      Value = YAML.load_file('$CONFIG_FILE');
   rescue Exception => e
      puts '${LOGTIME} [error] Load Failed,【' + e.message + '】';
   end;

   begin
   Thread.new{
      if Value['proxy-providers'] && Value['proxy-providers'].key?('Provider_9B46AF')
         Value['proxy-providers'].delete('Provider_9B46AF');
      end;
      if Value['proxy-groups']
         Value['proxy-groups'].each do |g|
            g['proxies']&.delete('Provider_9B46AF');
            g['use']&.delete('Provider_9B46AF');
            if (g['use'].nil? || g['use'].empty?) && (g['proxies'].nil? || g['proxies'].empty?)
               g.delete('use');
               g['proxies'] = ['DIRECT'];
            end;
         end;
      end;
   }.join;

   rescue Exception => e
      puts '${LOGTIME} [error] Cleanup failed,【' + e.message + '】';
   ensure
      File.open('$CONFIG_FILE','w') {|f| YAML.dump(Value, f)};
   end" 2>/dev/null >> $LOG_FILE
# ========== END ==========

# ========== 反作弊 + Ubisoft 直连规则注入 ==========
# 模板已有 🤖 AI服务/🎮 游戏平台/🤖 ChatGPT 等组，不再额外注入代理组
# 仅插入反作弊和 Ubisoft 直连规则（必须在 GEOSITE,category-games 之前）
LOG_OUT "Injecting anti-cheat DIRECT rules..."
ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   begin
      Value = YAML.load_file('$CONFIG_FILE');
   rescue Exception => e
      puts '${LOGTIME} [error] Load Failed,【' + e.message + '】';
   end;

   begin
   Thread.new{
      direct_ac_rules = [
         # BattlEye + EAC + Denuvo
         'DOMAIN-SUFFIX,battleye.b-cdn.net,DIRECT', 'DOMAIN-SUFFIX,cdn.battleye.com,DIRECT',
         'DOMAIN-SUFFIX,battleye.com,DIRECT', 'DOMAIN-SUFFIX,easyanticheat.net,DIRECT',
         'DOMAIN-SUFFIX,easy.ac,DIRECT', 'DOMAIN-SUFFIX,denuvo.com,DIRECT',
         'DOMAIN-SUFFIX,steamserver.net,DIRECT', 'DOMAIN-SUFFIX,equ8.com,DIRECT',
         # Ubisoft/R6 登录 — 不走代理
         'DOMAIN-SUFFIX,ubisoft.com,DIRECT', 'DOMAIN-SUFFIX,ubi.com,DIRECT',
         'DOMAIN-SUFFIX,uplay.com,DIRECT', 'DOMAIN-SUFFIX,ubisoftconnect.com,DIRECT',
         'DOMAIN-SUFFIX,rainbow6.com,DIRECT', 'DOMAIN-SUFFIX,rainbowsix.com,DIRECT',
         'DOMAIN-KEYWORD,ubisoft,DIRECT', 'DOMAIN-KEYWORD,rainbowsix,DIRECT',
         # Steam/Epic 下载 CDN
         'DOMAIN-SUFFIX,steamcontent.com,DIRECT', 'DOMAIN-SUFFIX,steamstatic.com,DIRECT',
         'DOMAIN-SUFFIX,epicgames.com,DIRECT', 'DOMAIN-SUFFIX,gog.com,DIRECT',
         # 奇游加速器
         'IP-CIDR,101.37.162.0/24,DIRECT', 'IP-CIDR,121.40.0.0/16,DIRECT',
         'IP-CIDR,47.99.0.0/16,DIRECT',
      ];
      # 插到 category-games 前面
      idx = Value['rules'].index { |r| r.to_s.include?('category-games') }
      if idx
         direct_ac_rules.reverse.each { |r| Value['rules'].insert(idx, r) }
      else
         Value['rules'] = direct_ac_rules + Value['rules']
      end;
      Value['rules'].uniq!;

      # DNS 设置补全 + 反作弊域名强制真解析
      Value['dns'] ||= {};
      Value['dns']['nameserver-policy'] ||= {};
      ['battleye.b-cdn.net','cdn.battleye.com','battleye.com',
       'easyanticheat.net','easy.ac','denuvo.com','equ8.com'
      ].each { |d| Value['dns']['nameserver-policy'][d] = '223.5.5.5' };

      Value['dns']['enable'] = true;
      Value['dns']['ipv6'] = false;
      Value['dns']['enhanced-mode'] = 'fake-ip';
      Value['dns']['fake-ip-range'] = '198.18.0.1/16';
      Value['dns']['listen'] = '0.0.0.0:7874';
      Value['dns']['respect-rules'] = true;
      Value['dns']['fake-ip-filter'] = ['geosite:cn'];
      Value['dns']['nameserver'] = ['192.168.1.1'];
      Value['dns']['default-nameserver'] = ['114.114.114.114', '119.29.29.29', '223.5.5.5'];
      Value['dns']['proxy-server-nameserver'] = ['192.168.1.1', '114.114.114.114', '119.29.29.29', '223.5.5.5'];
      # external-controller 绑定 0.0.0.0（否则 OpenClash 每次重置为 127.0.0.1）
      Value['external-controller'] = '0.0.0.0:9090';
   }.join;

   rescue Exception => e
      puts '${LOGTIME} [error] Direct rules failed,【' + e.message + '】';
   ensure
      File.open('$CONFIG_FILE','w') {|f| YAML.dump(Value, f)};
   end" 2>/dev/null >> $LOG_FILE
# ========== END ==========

# ========== DNS Rescue: 永久修复 DNS 死循环 ==========
# 三层拦截：
#  1. 关掉 OpenClash 的 redirect_dns，阻止 watchdog 回写
#  2. 删掉 nftables DNS 劫持规则（会绕过 dnsmasq 直接送 clash TUN）
#  3. dnsmasq 切到光猫上游 192.168.1.1，不再转发 clash:7874
REDIRECT=$(uci -q get openclash.config.enable_redirect_dns 2>/dev/null)
if [ "$REDIRECT" != "0" ]; then
   uci -q set openclash.config.enable_redirect_dns='0'
   uci -q set openclash.config.redirect_dns='0'
   uci commit openclash 2>/dev/null
   LOG_OUT "DNS Rescue: Disabled enable_redirect_dns"
fi

# 精确删除 nftables DNS 劫持规则（用 handle 而非 flush，保护端口转发等用户规则）
for chain in dstnat nat_output; do
   nft -a list chain inet fw4 $chain 2>/dev/null | \
      awk '/OpenClash DNS Hijack/{print $NF}' | \
      while read handle; do
         nft delete rule inet fw4 $chain handle "$handle" 2>/dev/null
         LOG_OUT "DNS Rescue: Deleted $chain DNS hijack rule (handle $handle)"
      done
done

CURRENT_DNS=$(uci -q get dhcp.@dnsmasq[0].server 2>/dev/null)
# dnsmasq 缓存修复：fake-IP 模式下设 0 合理，但 DNS Rescue 后直连光猫，需要缓存真实 IP
if [ "$(uci -q get dhcp.@dnsmasq[0].cachesize)" = "0" ]; then
   uci -q set dhcp.@dnsmasq[0].cachesize='150'
   uci -q set openclash.config.dnsmasq_cachesize='150'
   uci commit dhcp 2>/dev/null
   uci commit openclash 2>/dev/null
   LOG_OUT "DNS Rescue: Restored dnsmasq cachesize to 150 (was 0)"
fi
if echo "$CURRENT_DNS" | grep -q "127.0.0.1#7874"; then
   uci -q del_list dhcp.@dnsmasq[0].server='127.0.0.1#7874' 2>/dev/null
   uci -q add_list dhcp.@dnsmasq[0].server='192.168.1.1' 2>/dev/null
   uci commit dhcp 2>/dev/null
   /etc/init.d/dnsmasq restart 2>/dev/null
   LOG_OUT "DNS Rescue: dnsmasq upstream -> 192.168.1.1 (was 127.0.0.1#7874)"
else
   # 已修复：确保 fallback DNS 存在（光猫不可达时兜底）
   if ! echo "$CURRENT_DNS" | grep -q "114.114.114.114"; then
      uci -q add_list dhcp.@dnsmasq[0].server='114.114.114.114' 2>/dev/null
      uci -q add_list dhcp.@dnsmasq[0].server='223.5.5.5' 2>/dev/null
      uci commit dhcp 2>/dev/null
      /etc/init.d/dnsmasq restart 2>/dev/null
      LOG_OUT "DNS Rescue: Added fallback DNS (114.114.114.114, 223.5.5.5)"
   fi
fi

# cron 守护：每分钟检查 enable_redirect_dns 不被外部改回
if ! grep -q "enable_redirect_dns" /etc/crontabs/root 2>/dev/null; then
   echo '* * * * * [ "$(uci -q get openclash.config.enable_redirect_dns)" != "0" ] && uci -q set openclash.config.enable_redirect_dns=0 && uci commit openclash && echo "$(date) DNS Guard: reset enable_redirect_dns to 0" >> /tmp/openclash.log' >> /etc/crontabs/root
   /etc/init.d/cron restart 2>/dev/null
   LOG_OUT "DNS Rescue: Added cron guard for enable_redirect_dns"
fi
# ========== END DNS Rescue ==========

exit 0