#!/usr/bin/env bash
# sticky-test.sh: measure how long a sticky session really keeps the same exit IP.
# Every INTERVAL seconds it opens a NEW connection through the proxy and records the exit IP,
# then reports how long each IP lasted. Ctrl-C stops early and still prints the summary.
# Usage: ./sticky-test.sh 'http://SESSION_LOGIN:PASS@HOST:PORT' [interval_seconds=30] [minutes=30]
# Needs bash and curl. Maintained by Proxy302 (https://proxy302.com). MIT licence.
set -u
proxy="${1:?usage: $0 PROXY_URL [interval_seconds] [minutes]}"
interval="${2:-30}"
minutes="${3:-30}"
url="${CHECK_URL:-https://api.ipify.org}"
letters="ABCDEFGHIJKLMNOPQRSTUVWXYZ"

dur() {   # seconds -> m:ss or h:mm:ss
  local s=$1
  if [ "$s" -ge 3600 ]; then printf '%d:%02d:%02d' $((s / 3600)) $((s % 3600 / 60)) $((s % 60))
  else printf '%d:%02d' $((s / 60)) $((s % 60)); fi
}

seen=""                       # exit IPs in order of first appearance, one per line
tag() {                       # set T to the letter for IP $1
  local idx
  idx=$(printf '%s' "$seen" | grep -nxF -- "$1" | cut -d: -f1)
  if [ -z "$idx" ]; then seen="${seen}${1}"$'\n'; idx=$(printf '%s' "$seen" | grep -c .); fi
  if [ "$idx" -le 26 ]; then T="${letters:idx-1:1}"; else T="#$idx"; fi
}

runs=0; fails=0; checks=0     # a "run" is a stretch of checks that saw the same exit IP
run_tag=(); run_ip=(); run_first=(); run_last=(); run_next=()

summary() {
  echo
  echo "== Summary: $checks checks, $fails failed"
  local i lo hi
  for ((i = 0; i < runs; i++)); do
    lo=$((run_last[i] - run_first[i]))
    if [ -n "${run_next[i]}" ]; then
      hi=$((run_next[i] - run_first[i]))
      echo "  ${run_tag[i]}  ${run_ip[i]}  held at least $(dur $lo), changed before $(dur $hi)"
    else
      echo "  ${run_tag[i]}  ${run_ip[i]}  held at least $(dur $lo), still the exit when the test ended"
    fi
  done
  if [ "$runs" -eq 1 ]; then
    echo "The exit IP never changed during the test."
  elif [ "$runs" -gt 1 ]; then
    echo "$((runs - 1)) change(s). Real hold times lie between the two numbers on each line;"
    echo "a shorter interval narrows the gap."
  fi
  exit 0
}
trap summary INT

start=$(date +%s); stop=$((start + minutes * 60))
echo "Checking every ${interval}s for up to ${minutes} min, a new connection each time. Ctrl-C ends early."
printf '%-9s %8s  %s\n' "time" "elapsed" "exit"
while :; do
  now=$(date +%s); checks=$((checks + 1))
  ip=$(curl -s --max-time 20 -x "$proxy" "$url")
  if [ $? -ne 0 ] || [ -z "$ip" ]; then
    fails=$((fails + 1))
    printf '%-9s %8s  -  check failed\n' "$(date +%H:%M:%S)" "$(dur $((now - start)))"
  else
    tag "$ip"; note=""
    if [ "$runs" -eq 0 ] || [ "${run_ip[runs-1]}" != "$ip" ]; then
      if [ "$runs" -gt 0 ]; then
        run_next[runs-1]=$now
        note="   <- changed from ${run_tag[runs-1]} after $(dur $((run_last[runs-1] - run_first[runs-1]))) to $(dur $((now - run_first[runs-1])))"
      fi
      run_tag[runs]=$T; run_ip[runs]=$ip; run_first[runs]=$now; run_next[runs]=""; runs=$((runs + 1))
    fi
    run_last[runs-1]=$now
    printf '%-9s %8s  %s  %s%s\n' "$(date +%H:%M:%S)" "$(dur $((now - start)))" "$T" "$ip" "$note"
  fi
  [ $(( $(date +%s) + interval )) -gt "$stop" ] && break
  sleep "$interval"
done
summary
