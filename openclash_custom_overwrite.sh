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

# ========== 自定义 🤖 AI 代理组 + 规则注入 ==========
LOG_OUT "Injecting 🤖 AI proxy group and rules..."
ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "
   begin
      Value = YAML.load_file('$CONFIG_FILE');
   rescue Exception => e
      puts '${LOGTIME} [error] Load File Failed,【' + e.message + '】';
   end;

   begin
   Thread.new{
      Value['proxy-groups'] ||= [];
      unless Value['proxy-groups'].any? { |g| g['name'] == '🤖 AI' }
               # 🎮 游戏代理组 — 手动选择节点
      Value['proxy-groups'].unshift({
         'name' => '🎮 游戏',
         'type' => 'select',
         'proxies' => ['♻️ 自动选择', '🔰 节点选择', 'DIRECT']
      });

      Value['proxy-groups'].unshift({
            'name' => '🤖 AI',
            'type' => 'select',
            'proxies' => ['♻️ 自动选择', '🔰 节点选择', 'DIRECT']
         });
      end;

      ai_rules = [
         'DOMAIN-SUFFIX,openai.com,🤖 AI',
         'DOMAIN-SUFFIX,chatgpt.com,🤖 AI',
         'DOMAIN-SUFFIX,oaistatic.com,🤖 AI',
         'DOMAIN-SUFFIX,oaiusercontent.com,🤖 AI',
         'DOMAIN-SUFFIX,anthropic.com,🤖 AI',
         'DOMAIN-SUFFIX,claude.ai,🤖 AI',
         'DOMAIN-SUFFIX,gemini.google.com,🤖 AI',
         'DOMAIN-SUFFIX,bard.google.com,🤖 AI',
         'DOMAIN-SUFFIX,ai.google.dev,🤖 AI',
         'DOMAIN-SUFFIX,generativelanguage.googleapis.com,🤖 AI',
         'DOMAIN-SUFFIX,copilot.microsoft.com,🤖 AI',
         'DOMAIN-KEYWORD,perplexity,🤖 AI',
         'DOMAIN-SUFFIX,poe.com,🤖 AI',
         'DOMAIN-SUFFIX,character.ai,🤖 AI',
         'DOMAIN-SUFFIX,cursor.sh,🤖 AI',
         'DOMAIN-SUFFIX,cursor.com,🤖 AI',
         'DOMAIN-SUFFIX,huggingface.co,🤖 AI'
      ];
      Value['rules'] ||= [];
      Value['rules'] = ai_rules + Value['rules'];
      Value['rules'].uniq!;

      # 🎮 Ubisoft/R6 游戏流量 — 走代理最快节点
      r6_game_rules = [
         'DOMAIN-SUFFIX,ubisoft.com,🎮 游戏',
         'DOMAIN-SUFFIX,ubi.com,🎮 游戏',
         'DOMAIN-SUFFIX,uplay.com,🎮 游戏',
         'DOMAIN-SUFFIX,ubisoftconnect.com,🎮 游戏',
         'DOMAIN-SUFFIX,ubisoft.org,🎮 游戏',
         'DOMAIN-SUFFIX,ubisoftcdn.com,🎮 游戏',
         'DOMAIN-SUFFIX,rainbow6.com,🎮 游戏',
         'DOMAIN-SUFFIX,rainbowsix.com,🎮 游戏',
         'DOMAIN-SUFFIX,rainbowsixgame.com,🎮 游戏',
         'DOMAIN-SUFFIX,r6s.ubi.com,🎮 游戏',
         'DOMAIN-SUFFIX,r6stats.com,🎮 游戏',
         'DOMAIN-SUFFIX,ubisoft-patch.com,🎮 游戏',
         'DOMAIN-SUFFIX,ubisoft-download.com,🎮 游戏',
         'DOMAIN-KEYWORD,ubisoft,🎮 游戏',
         'DOMAIN-KEYWORD,rainbowsix,🎮 游戏'
      ];
      Value['rules'] = r6_game_rules + Value['rules'];
      Value['rules'].uniq!;

      # 🎮 Rockstar 游戏流量 — 走最快节点
      rstar_game_rules = [
         'DOMAIN-SUFFIX,rockstargames.com,🎮 游戏',
         'DOMAIN-SUFFIX,rockstarnorth.com,🎮 游戏',
         'DOMAIN-SUFFIX,socialclub.rockstargames.com,🎮 游戏',
         'DOMAIN-SUFFIX,rockstarsocialclub.net,🎮 游戏',
         'DOMAIN-SUFFIX,gtav.com,🎮 游戏',
         'DOMAIN-SUFFIX,reddeadonline.com,🎮 游戏',
         'DOMAIN-SUFFIX,rgsc.io,🎮 游戏',
         'DOMAIN-SUFFIX,rsg.sc,🎮 游戏',
         'DOMAIN-KEYWORD,rockstar,🎮 游戏'
      ];
      Value['rules'] = rstar_game_rules + Value['rules'];
      Value['rules'].uniq!;

# 🛡 反作弊/游戏后端 — 必须直连，走代理必挂
      game_direct_rules = [
         # BattlEye
         'DOMAIN-SUFFIX,battleye.b-cdn.net,DIRECT',
         'DOMAIN-SUFFIX,cdn.battleye.com,DIRECT',
         'DOMAIN-SUFFIX,battleye.com,DIRECT',
         # EasyAntiCheat (EAC) — Fortnite/Apex/Division 等
         'DOMAIN-SUFFIX,easyanticheat.net,DIRECT',
         'DOMAIN-SUFFIX,easy.ac,DIRECT',
         # Denuvo Anti-Cheat
         'DOMAIN-SUFFIX,denuvo.com,DIRECT',
         # Valve Anti-Cheat (VAC) + Steam 后端
         'DOMAIN-SUFFIX,steamserver.net,DIRECT',
         # EQU8
         'DOMAIN-SUFFIX,equ8.com,DIRECT',

         # Epic Online Services
         'DOMAIN-SUFFIX,eos-cdn.com,DIRECT',
         'DOMAIN-SUFFIX,epicgames.dev,DIRECT',
         # EA / Origin
         'DOMAIN-SUFFIX,ea.com,DIRECT',
         'DOMAIN-SUFFIX,origin.com,DIRECT',

         # 🎮 Steam 下载 CDN — 直连满速
         'DOMAIN-SUFFIX,steamcontent.com,DIRECT',
         'DOMAIN-SUFFIX,steamcdn.com,DIRECT',
         'DOMAIN-SUFFIX,steamstatic.com,DIRECT',
         'DOMAIN-SUFFIX,steamcommunity.com,DIRECT',
         'DOMAIN-SUFFIX,steampowered.com,DIRECT',
         'DOMAIN-SUFFIX,steam-chat.com,DIRECT',
         'DOMAIN-SUFFIX,akamaihd.net,DIRECT',
         'DOMAIN-SUFFIX,cloudflaresteam.com,DIRECT',
         'DOMAIN-SUFFIX,valvesoftware.com,DIRECT',
         # 🎮 Epic Games 下载 CDN
         'DOMAIN-SUFFIX,epicgames.com,DIRECT',
         'DOMAIN-SUFFIX,ol.epicgames.com,DIRECT',
         'DOMAIN-SUFFIX,download.epicgames.com,DIRECT',
         'DOMAIN-SUFFIX,download2.epicgames.com,DIRECT',
         'DOMAIN-SUFFIX,download3.epicgames.com,DIRECT',
         'DOMAIN-SUFFIX,download4.epicgames.com,DIRECT',
         'DOMAIN-SUFFIX,epicgames-download1.akamaized.net,DIRECT',
         'DOMAIN-SUFFIX,fastly.steamstatic.com,DIRECT',
         'DOMAIN-KEYWORD,epicgamescdn,DIRECT',
         # 🎮 通用游戏 CDN
         'DOMAIN-SUFFIX,gog.com,DIRECT',
         'DOMAIN-SUFFIX,gog-statics.com,DIRECT',
         'DOMAIN-SUFFIX,gog.qtlglb.com,DIRECT',
         'DOMAIN-SUFFIX,battle.net,DIRECT',
         'DOMAIN-SUFFIX,blizzard.com,DIRECT',
         'DOMAIN-SUFFIX,blzstatic.cn,DIRECT'
      ];
      # 🚀 奇游加速器中继 IP — 必须直连，否则加速器隧道被 OpenClash 废掉
      # IP 动态变化，每次启动需更新。同时用 /24 段覆盖减少遗漏
      qiyou_relay_ips = [
         'IP-CIDR,101.37.162.0/24,DIRECT',
         'IP-CIDR,112.83.140.0/24,DIRECT',
         'IP-CIDR,116.162.32.0/20,DIRECT',
         'IP-CIDR,121.40.0.0/16,DIRECT',
         'IP-CIDR,122.248.50.0/24,DIRECT',
         'IP-CIDR,162.14.126.0/24,DIRECT',
         'IP-CIDR,221.15.71.0/24,DIRECT',
         'IP-CIDR,27.44.0.0/16,DIRECT',
         'IP-CIDR,47.99.0.0/16,DIRECT',
         'IP-CIDR,58.144.0.0/16,DIRECT',
         'IP-CIDR,61.240.206.0/24,DIRECT',
         'IP-CIDR,1.14.0.0/16,DIRECT'
      ];
      Value['rules'] = game_direct_rules + qiyou_relay_ips + Value['rules'];
      Value['rules'].uniq!;

      # DNS 强制真解析：反作弊域名绕过 fake-ip
      Value['dns'] ||= {};
      Value['dns']['nameserver-policy'] ||= {};
      dns_direct_domains = [
         'battleye.b-cdn.net',
         'cdn.battleye.com',
         'battleye.com',
         'easyanticheat.net',
         'easy.ac',
         'denuvo.com',
         'equ8.com'
      ];
      dns_direct_domains.each { |d| Value['dns']['nameserver-policy'][d] = '223.5.5.5' };

      # 显式写入 DNS 设置，防止 YAML.dump 丢失模板配置
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
   }.join;

   rescue Exception => e
      puts '${LOGTIME} [error] Set AI Group Failed,【' + e.message + '】';
   ensure
      File.open('$CONFIG_FILE','w') {|f| YAML.dump(Value, f)};
   end" 2>/dev/null >> $LOG_FILE
# ========== END ==========

# ========== DNS Rescue: 修复 dnsmasq 向 clash 7874 转发导致的 DNS 死循环 ==========
# OpenClash 会将 dnsmasq 上游设为 127.0.0.1#7874（clash DNS），
# 但 clash DNS 在 fake-ip 模式下对直连域名不响应，导致全部 DNS 超时。
# 此修复将 dnsmasq 上游切回光猫 DNS（192.168.1.1），国内秒开、国外走 TUN
# 每次执行都检查 — OpenClash 会反复回写 127.0.0.1#7874
CURRENT_DNS=$(uci -q get dhcp.@dnsmasq[0].server 2>/dev/null)
if echo "$CURRENT_DNS" | grep -q "127.0.0.1#7874"; then
   uci -q del_list dhcp.@dnsmasq[0].server='127.0.0.1#7874' 2>/dev/null
   uci -q add_list dhcp.@dnsmasq[0].server='192.168.1.1' 2>/dev/null
   uci commit dhcp 2>/dev/null
   /etc/init.d/dnsmasq restart 2>/dev/null &
   LOG_OUT "DNS Rescue: Fixed dnsmasq upstream (was 127.0.0.1#7874 -> 192.168.1.1)"
fi
# ========== END DNS Rescue ==========

exit 0