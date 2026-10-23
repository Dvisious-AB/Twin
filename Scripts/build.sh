#!/bin/bash
set -e
./Scripts/generate.sh
xcodebuild -scheme Twin -configuration Debug -destination 'platform=macOS' build
