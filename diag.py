#!/usr/bin/env python3
"""OpenClash 诊断工具 — 通过 paramiko SSH 检查路由器状态

用法:
  python diag.py                          # 交互式输入密码
  python diag.py -p BSC-a0312.            # 命令行传入密码
  python diag.py -i 192.168.8.1 -p xxx    # 指定 IP 和密码
  python diag.py -i 192.168.8.1 -p xxx --check  # 仅检查 DNS（精简模式）
  python diag.py -i 192.168.8.1 -p xxx --fix    # 诊断 + 修复常见问题

检查项: GeoIP.dat 完整性、enable 状态、运行进程、日志、overwrite 脚本、DNS 配置
"""

import argparse
import os
import sys
import paramiko


def ssh_cmd(ssh, cmd, timeout=15):
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    if err:
        print(f"  [stderr] {err}")
    return out


def diagnose(ssh):
    """Full diagnosis of OpenClash status."""
    print("=" * 50)
    print(" OpenClash Diagnosis")
    print("=" * 50)

    # 1. GeoIP.dat
    print("\n--- [1] GeoIP.dat ---")
    out = ssh_cmd(ssh, "ls -la /etc/openclash/GeoIP.dat 2>&1")
    print(f"  {out}")
    if "No such file" in out:
        print("  => MISSING!")
    else:
        parts = out.split()
        if len(parts) >= 5:
            try:
                size = int(parts[4])
                if size < 10000:
                    print(f"  => CORRUPTED! Size={size} bytes (normal ~18MB)")
                elif size < 5000000:
                    print(f"  => SUSPICIOUS! Size={size/1e6:.1f} MB")
                else:
                    print(f"  => OK ({size/1e6:.1f} MB)")
            except ValueError:
                pass

    # 2. Enable status
    print("\n--- [2] OpenClash Status ---")
    enabled = ssh_cmd(ssh, "uci get openclash.config.enable 2>&1")
    print(f"  enable={enabled}")
    proc_out = ssh_cmd(ssh, "ps | grep '/etc/openclash/clash' | grep -v grep")
    if proc_out.strip():
        print(f"  Process: RUNNING")
    else:
        print("  Process: NOT running")

    # 3. DNS config (key check for death-loop)
    print("\n--- [3] DNS Config ---")
    dns = ssh_cmd(ssh, "uci show dhcp.@dnsmasq[0] 2>&1 | grep server")
    print(f"  dnsmasq upstream: {dns}")
    if "127.0.0.1#7874" in dns:
        print("  => WARNING: DNS death loop risk! Should be 192.168.1.1")

    # 4. Recent log
    print("\n--- [4] Recent Log (last 10 lines) ---")
    log = ssh_cmd(ssh, "tail -10 /tmp/openclash.log 2>&1")
    for line in log.split("\n")[-5:]:
        if line.strip():
            safe = line.encode("ascii", errors="replace").decode("ascii")
            print(f"  {safe[:150]}")

    # 5. Overwrite script
    print("\n--- [5] Overwrite Script ---")
    out = ssh_cmd(ssh, "ls -la /etc/openclash/custom/openclash_custom_overwrite.sh 2>&1")
    print(f"  {out}")

    # 6. Proxy groups count
    print("\n--- [6] Config Snapshot ---")
    groups = ssh_cmd(ssh, "grep -c 'name:' /etc/openclash/config/bsc.yaml 2>&1")
    rules = ssh_cmd(ssh, "grep -c 'DIRECT\|GEOIP\|MATCH\|DOMAIN' /etc/openclash/config/bsc.yaml 2>&1")
    print(f"  Proxy groups: {groups}, Rules: {rules}")

    print("\n" + "=" * 50)
    print(" Diagnosis complete.")
    print("=" * 50)


def quick_check(ssh):
    """Quick connectivity check (DNS + HTTP)."""
    print("Quick Check:")
    # DNS
    dns = ssh_cmd(ssh, "uci show dhcp.@dnsmasq[0] 2>&1 | grep server", timeout=5)
    print(f"  DNS upstream: {dns}")

    # HTTP
    for name, url in [("baidu", "http://www.baidu.com"), ("google", "https://www.google.com")]:
        out = ssh_cmd(ssh, f'curl -s -o /dev/null -w "%{{http_code}}" --connect-timeout 5 {url} 2>&1', timeout=10)
        print(f"  {name}: HTTP {out}")

    # Proxy
    out = ssh_cmd(ssh, 'curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 -x http://127.0.0.1:7890 https://www.google.com 2>&1', timeout=10)
    print(f"  google(proxy): HTTP {out}")


def fix(ssh):
    """Fix common OpenClash issues."""
    print("Applying fixes...")

    # 1. Enable OpenClash
    enabled = ssh_cmd(ssh, "uci get openclash.config.enable 2>&1")
    if enabled != "1":
        print("  [1] Enabling OpenClash...")
        ssh_cmd(ssh, "uci set openclash.config.enable=1 && uci commit openclash")
        print("  Done.")

    # 2. DNS Rescue
    dns = ssh_cmd(ssh, "uci show dhcp.@dnsmasq[0] 2>&1 | grep server")
    if "127.0.0.1#7874" in dns:
        print("  [2] Fixing DNS death loop...")
        ssh_cmd(ssh, "uci -q del_list dhcp.@dnsmasq[0].server='127.0.0.1#7874' 2>/dev/null")
        ssh_cmd(ssh, "uci -q add_list dhcp.@dnsmasq[0].server='192.168.1.1' 2>/dev/null")
        ssh_cmd(ssh, "uci commit dhcp 2>/dev/null")
        ssh_cmd(ssh, "/etc/init.d/dnsmasq restart 2>/dev/null")
        print("  Done.")

    # 3. Restart if needed
    proc = ssh_cmd(ssh, "ps | grep '/etc/openclash/clash' | grep -v grep")
    if not proc.strip():
        print("  [3] Starting OpenClash...")
        ssh_cmd(ssh, "/etc/init.d/openclash start 2>&1", timeout=30)
        import time
        time.sleep(5)
    print("  Done.")


def main():
    parser = argparse.ArgumentParser(
        description="OpenClash router diagnosis via SSH")
    parser.add_argument("-i", "--ip", default="192.168.8.1",
                        help="Router IP (default: 192.168.8.1)")
    parser.add_argument("-p", "--password", default=None,
                        help="SSH password")
    parser.add_argument("-u", "--user", default="root",
                        help="SSH user (default: root)")
    parser.add_argument("--check", action="store_true",
                        help="Quick connectivity check only")
    parser.add_argument("--fix", action="store_true",
                        help="Diagnose and fix common issues")
    parser.add_argument("--upload", metavar="LOCAL_FILE",
                        help="Upload overwrite script to router")
    args = parser.parse_args()

    password = args.password or os.environ.get("OCLASH_PW")
    if not password:
        import getpass
        password = getpass.getpass(f"SSH password for {args.user}@{args.ip}: ")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(args.ip, username=args.user, password=password,
                       timeout=10, allow_agent=False, look_for_keys=False)
    except paramiko.AuthenticationException:
        print("ERROR: Authentication failed. Check password.")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Connection failed: {e}")
        sys.exit(1)

    try:
        # Upload mode
        if args.upload:
            src = args.upload
            dst = "/etc/openclash/custom/openclash_custom_overwrite.sh"
            print(f"Uploading {src} -> {dst} ...")
            with open(src, "r", encoding="utf-8") as f:
                content = f.read()
            channel = client.get_transport().open_session()
            channel.exec_command(f"cat > {dst}")
            channel.sendall(content.encode("utf-8"))
            channel.shutdown_write()
            channel.recv_exit_status()
            ssh_cmd(client, f"chmod +x {dst}")
            print("Upload OK.")
            return

        if args.check:
            quick_check(client)
        elif args.fix:
            diagnose(client)
            print()
            fix(client)
            print()
            quick_check(client)
        else:
            diagnose(client)

    finally:
        client.close()


if __name__ == "__main__":
    main()
