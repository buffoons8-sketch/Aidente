#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
build_dir="$project_dir/Build"
module_dir="$build_dir/Modules"
object_dir="$build_dir/Objects"
module_cache_dir="$build_dir/ModuleCache"
dist_dir="$project_dir/Dist"
app_dir="$dist_dir/Aidente.app"
sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk"
target="arm64-apple-macosx14.0"

if [[ ! -d "$sdk" ]]; then
    sdk=$(xcrun --sdk macosx --show-sdk-path)
fi

mkdir -p "$module_dir" "$object_dir" "$module_cache_dir" "$dist_dir"

clang \
    -c "$project_dir/Vendor/SMCKit/Sources/SMC/smc.c" \
    -I "$project_dir/Vendor/SMCKit/Sources/SMC/include" \
    -isysroot "$sdk" \
    -mmacosx-version-min=14.0 \
    -fmodules \
    -fmodules-cache-path="$module_cache_dir" \
    -o "$object_dir/smc.o"

swiftc \
    -parse-as-library \
    -emit-module \
    -emit-module-path "$module_dir/SMCKit.swiftmodule" \
    -emit-library \
    -static \
    -module-name SMCKit \
    "$project_dir"/Vendor/SMCKit/Sources/SMCKit/*.swift \
    -I "$project_dir/Vendor/SMCKit/Sources/SMC/include" \
    -sdk "$sdk" \
    -target "$target" \
    -module-cache-path "$module_cache_dir" \
    -o "$build_dir/libSMCKit.a"

swiftc \
    -parse-as-library \
    -emit-module \
    -emit-module-path "$module_dir/Defaults.swiftmodule" \
    -emit-library \
    -static \
    -module-name Defaults \
    "$project_dir"/Vendor/Defaults/Sources/Defaults/*.swift \
    -sdk "$sdk" \
    -target "$target" \
    -module-cache-path "$module_cache_dir" \
    -o "$build_dir/libDefaults.a"

swiftc \
    -parse-as-library \
    -emit-module \
    -emit-module-path "$module_dir/AidenteShared.swiftmodule" \
    -emit-library \
    -static \
    -module-name AidenteShared \
    "$project_dir"/Shared/*.swift \
    -sdk "$sdk" \
    -target "$target" \
    -module-cache-path "$module_cache_dir" \
    -o "$build_dir/libAidenteShared.a"

swiftc \
    -parse-as-library \
    -emit-module \
    -emit-module-path "$module_dir/smc_power.swiftmodule" \
    -emit-library \
    -static \
    -module-name smc_power \
    "$project_dir"/SMCPower/*.swift \
    -I "$module_dir" \
    -I "$project_dir/Vendor/SMCKit/Sources/SMC/include" \
    -sdk "$sdk" \
    -target "$target" \
    -module-cache-path "$module_cache_dir" \
    -o "$build_dir/libsmc_power.a"

app_sources=("$project_dir"/Aidente/**/*.swift)

swiftc \
    -parse-as-library \
    -swift-version 5 \
    -strict-concurrency=minimal \
    -module-name Aidente \
    "${app_sources[@]}" \
    -I "$module_dir" \
    -L "$build_dir" \
    -lDefaults \
    -lAidenteShared \
    -lsmc_power \
    -lSMCKit \
    "$object_dir/smc.o" \
    -I "$project_dir/Vendor/SMCKit/Sources/SMC/include" \
    -framework AppKit \
    -framework SwiftUI \
    -framework IOKit \
    -framework ServiceManagement \
    -framework UserNotifications \
    -sdk "$sdk" \
    -target "$target" \
    -module-cache-path "$module_cache_dir" \
    -o "$build_dir/Aidente"

swiftc \
    -swift-version 5 \
    -strict-concurrency=minimal \
    -module-name AidenteReader \
    "$project_dir/Helper/Helper.swift" \
    "$project_dir/Helper/main.swift" \
    -I "$module_dir" \
    -L "$build_dir" \
    -lAidenteShared \
    -lsmc_power \
    -lSMCKit \
    "$object_dir/smc.o" \
    -I "$project_dir/Vendor/SMCKit/Sources/SMC/include" \
    -framework Foundation \
    -framework IOKit \
    -sdk "$sdk" \
    -target "$target" \
    -module-cache-path "$module_cache_dir" \
    -o "$build_dir/AidenteReader"

swiftc \
    -swift-version 5 \
    -strict-concurrency=minimal \
    -module-name AidenteControl \
    "$project_dir/ChargingHelper/ChargingHelper.swift" \
    "$project_dir/ChargingHelper/main.swift" \
    -I "$module_dir" \
    -L "$build_dir" \
    -lAidenteShared \
    -lsmc_power \
    -lSMCKit \
    "$object_dir/smc.o" \
    -I "$project_dir/Vendor/SMCKit/Sources/SMC/include" \
    -framework Foundation \
    -framework IOKit \
    -framework Security \
    -sdk "$sdk" \
    -target "$target" \
    -module-cache-path "$module_cache_dir" \
    -o "$build_dir/AidenteControl"

if [[ -e "$app_dir" ]]; then
    previous_app="$dist_dir/Aidente.previous.$(date +%Y%m%d%H%M%S).app"
    mv "$app_dir" "$previous_app"
fi

mkdir -p \
    "$app_dir/Contents/MacOS" \
    "$app_dir/Contents/Resources" \
    "$app_dir/Contents/XPCServices/com.aidente.app.reader.xpc/Contents/MacOS" \
    "$app_dir/Contents/Library/LaunchDaemons"

cp "$build_dir/Aidente" "$app_dir/Contents/MacOS/Aidente"
cp "$project_dir/BuildSupport/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/LICENSE" "$app_dir/Contents/Resources/LICENSE.txt"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$app_dir/Contents/Resources/THIRD_PARTY_NOTICES.md"

reader_dir="$app_dir/Contents/XPCServices/com.aidente.app.reader.xpc"
cp "$build_dir/AidenteReader" "$reader_dir/Contents/MacOS/AidenteReader"
cp "$project_dir/BuildSupport/ReaderInfo.plist" "$reader_dir/Contents/Info.plist"

cp "$build_dir/AidenteControl" "$app_dir/Contents/MacOS/AidenteControl"
# 0.2.0 registered this legacy relative path. Keep a signed compatibility
# copy for one upgrade cycle so macOS background-item metadata cached from the
# Keep a signed copy in the launch-daemon directory for macOS background-item
# registration compatibility.
cp "$build_dir/AidenteControl" "$app_dir/Contents/Library/LaunchDaemons/AidenteControl"
cp \
    "$project_dir/ChargingHelper/com.aidente.app.control.plist" \
    "$app_dir/Contents/Library/LaunchDaemons/com.aidente.app.control.plist"

icon_source="$build_dir/Aidente-icon-1024.png"
icon_generator="$build_dir/generate-icon"
iconset="$build_dir/Aidente.iconset"
swiftc \
    "$project_dir/BuildSupport/generate_icon.swift" \
    -framework AppKit \
    -sdk "$sdk" \
    -target "$target" \
    -o "$icon_generator"
"$icon_generator" "$icon_source"
mkdir -p "$iconset"
sips -z 16 16 "$icon_source" --out "$iconset/icon_16x16.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset/icon_32x32.png" >/dev/null
sips -z 64 64 "$icon_source" --out "$iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$icon_source" --out "$iconset/icon_128x128.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset/icon_256x256.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset/icon_512x512.png" >/dev/null
cp "$icon_source" "$iconset/icon_512x512@2x.png"
iconutil -c icns "$iconset" -o "$app_dir/Contents/Resources/Aidente.icns"

codesign \
    --force \
    --sign - \
    --timestamp=none \
    --identifier com.aidente.app.control \
    "$app_dir/Contents/MacOS/AidenteControl"
codesign \
    --force \
    --sign - \
    --timestamp=none \
    --identifier com.aidente.app.control \
    "$app_dir/Contents/Library/LaunchDaemons/AidenteControl"
codesign \
    --force \
    --sign - \
    --timestamp=none \
    --identifier com.aidente.app.reader \
    "$reader_dir"
codesign \
    --force \
    --sign - \
    --timestamp=none \
    --identifier com.aidente.app \
    "$app_dir"

codesign --verify --deep --strict --verbose=2 "$app_dir"
echo "$app_dir"
