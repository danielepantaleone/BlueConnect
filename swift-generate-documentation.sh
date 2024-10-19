#!/bin/sh

swift build

swift package \
     --allow-writing-to-directory ./docs \
     generate-documentation \
     --target BlueConnect \
     --transform-for-static-hosting \
     --hosting-base-path BlueConnect \
     --output-path ./docs
