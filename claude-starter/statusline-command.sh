#!/bin/bash
input=$(cat)

used_pct=$(echo "$input" | grep -o '"used_percentage":[0-9.]*' | head -1 | sed 's/"used_percentage"://')
ctx_size=$(echo "$input" | grep -o '"context_window_size":[0-9]*' | head -1 | sed 's/"context_window_size"://')
input_tk=$(echo "$input" | grep -o '"input_tokens":[0-9]*' | head -1 | sed 's/"input_tokens"://')
output_tk=$(echo "$input" | grep -o '"output_tokens":[0-9]*' | head -1 | sed 's/"output_tokens"://')
cache_create=$(echo "$input" | grep -o '"cache_creation_input_tokens":[0-9]*' | head -1 | sed 's/"cache_creation_input_tokens"://')
cache_read=$(echo "$input" | grep -o '"cache_read_input_tokens":[0-9]*' | head -1 | sed 's/"cache_read_input_tokens"://')
cost=$(echo "$input" | grep -o '"total_cost_usd":[0-9.]*' | head -1 | sed 's/"total_cost_usd"://')
rate_5h=$(echo "$input" | grep -o '"five_hour":{[^}]*}' | grep -o '"used_percentage":[0-9.]*' | sed 's/"used_percentage"://')
rate_7d=$(echo "$input" | grep -o '"seven_day":{[^}]*}' | grep -o '"used_percentage":[0-9.]*' | sed 's/"used_percentage"://')

pct=$([ -n "$used_pct" ] && printf "%.0f%%" "$used_pct" || echo "--")

if [ -n "$input_tk" ]; then
    total_used=$(( ${input_tk:-0} + ${output_tk:-0} + ${cache_create:-0} + ${cache_read:-0} ))
    tokens="$(( total_used / 1000 ))K/$(( ${ctx_size:-1000000} / 1000 ))K"
else
    tokens="--"
fi

cost_str=$([ -n "$cost" ] && printf "\$%.2f" "$cost" || echo "--")
r5h=$([ -n "$rate_5h" ] && printf "%.0f%%" "$rate_5h" || echo "--")
r7d=$([ -n "$rate_7d" ] && printf "%.0f%%" "$rate_7d" || echo "--")

printf "\033[33m%s\033[0m \033[36m%s\033[0m \033[32m%s\033[0m \033[35m5h:%s\033[0m \033[34m7d:%s\033[0m" "$pct" "$tokens" "$cost_str" "$r5h" "$r7d"
