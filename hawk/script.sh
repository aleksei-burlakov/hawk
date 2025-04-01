#!/bin/bash
set -e

echo "🧽 Cleaning Gemfile.lock to keep only 'ruby' platform..."

# Remove all but 'ruby' in the PLATFORMS section
awk '
BEGIN { in_platforms = 0 }
$1 == "PLATFORMS" { in_platforms = 1; print; next }
in_platforms && $1 ~ /^[^ ]/ { in_platforms = 0 }
in_platforms { if ($1 == "ruby") print; next }
{ print }
' Gemfile.lock > Gemfile.lock.cleaned

mv Gemfile.lock.cleaned Gemfile.lock

# Remove native variants like ffi (1.17.1-x86_64-linux-gnu)
sed -i '/ffi (1\.17\.1-[^)]*)/d' Gemfile.lock
sed -i '/nokogiri (1\.18\.5-[^)]*)/d' Gemfile.lock

echo "✅ Gemfile.lock cleaned."

