#!/bin/sh

swift build

swift package \
     --allow-writing-to-directory ./Documentation \
     generate-documentation \
     --target BlueConnect \
     --transform-for-static-hosting \
     --hosting-base-path BlueConnect \
     --output-path ./Documentation
