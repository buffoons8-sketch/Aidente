#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h:h}
cd "$project_dir"
sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk"
if [[ ! -d "$sdk" ]]; then
    sdk=$(xcrun --sdk macosx --show-sdk-path)
fi
swiftc -parse-as-library BuildSupport/tests/ChargingRegressionTests.swift \
    -sdk "$sdk" -target arm64-apple-macosx14.0 \
    -I Build/Modules -I Vendor/SMCKit/Sources/SMC/include \
    -L Build -lAidenteShared -lsmc_power -lSMCKit Build/Objects/smc.o \
    -framework IOKit -o Build/ChargingRegressionTests
Build/ChargingRegressionTests
