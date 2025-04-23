#!/bin/bash

# Check for required tools
for tool in gau waybackurls katana; do
  if ! command -v $tool &> /dev/null; then
    echo "[!] Error: '$tool' not found. Please install it before running the script."
    exit 1
  fi
done

# Check if a domain was provided
if [ -z "$1" ]; then
  echo "[!] Usage: bash $0 <domain>"
  exit 1
fi

DOMAIN="$1"
CLEAN_DOMAIN=$(echo "$DOMAIN" | sed -E 's~https?://~~; s~/.*~~')
root_dir="recon_${CLEAN_DOMAIN}"

mkdir -p "$root_dir/urls" "$root_dir/params"

echo "[*] Target: $DOMAIN"
echo "[*] Gathering URLs with gau..."
gau "$DOMAIN" --threads 10 --o "$root_dir/urls/gau.txt"
echo "[*] gau results saved in $root_dir/urls/gau.txt"

echo "-------------------------------------------------------------------------"
echo "[*] Gathering URLs with waybackurls..."
waybackurls "$DOMAIN" > "$root_dir/urls/waybacks.txt"
echo "[*] waybackurls results saved in $root_dir/urls/waybacks.txt"

echo "-------------------------------------------------------------------------"
echo "[*] Running Katana Crawler..."
katana -u "$DOMAIN" -headless -d 5 -jc -rl 10 --no-sandbox -o "$root_dir/urls/katana.txt"
echo "[*] Katana results saved in $root_dir/urls/katana.txt"

echo "-------------------------------------------------------------------------"
echo "[*] Merging and cleaning URLs..."
cat "$root_dir/urls/"*.txt | sed 's/;//g' | grep -Eo 'https?://[^"]+' | sort -u > "$root_dir/urls/all_clean.txt"
echo "[*] Cleaned URLs saved in $root_dir/urls/all_clean.txt"

echo "-------------------------------------------------------------------------"
echo "[*] Extracting parameter names and param-value pairs..."

# 1. Pure parameter name wordlist
grep '=' "$root_dir/urls/all_clean.txt" | grep -oP '(?<=\?|&)[^=]+(?==)' | sort -u > "$root_dir/params/param_wordlist.txt"

# 2. Param,value,source_url CSV file
> "$root_dir/params/param_value_pairs.csv"

total=$(wc -l < "$root_dir/urls/all_clean.txt")
count=0

while IFS= read -r url; do
  ((count++))
  echo -ne "\r[*] Processing $count / $total URLs..."

  # Extract only the query string
  query_string=$(echo "$url" | grep -oP '\?.*' | sed 's/^\?//')
  [[ -z "$query_string" ]] && continue

  IFS='&' read -ra pairs <<< "$query_string"
  for pair in "${pairs[@]}"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    if [[ -n "$key" && -n "$value" && "$key" != "$value" ]]; then
      echo "$key,$value,$url" >> "$root_dir/params/param_value_pairs.csv"
    fi
  done
done < "$root_dir/urls/all_clean.txt"

sort -u "$root_dir/params/param_value_pairs.csv" -o "$root_dir/params/param_value_pairs.csv"

echo -e "\n[*] Wordlist saved at: $root_dir/params/param_wordlist.txt"
echo "[*] CSV with values and source URLs saved at: $root_dir/params/param_value_pairs.csv"
echo "-------------------------------------------------------------------------"
echo "[✓] Recon and wordlist generation complete!"
