#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
OUTPUT_ROOT="${1:-$ROOT/AppStore/screenshots-raw}"
RESULT_ROOT="$ROOT/build/AppStoreScreenshotResults"

typeset -A DEVICES
DEVICES[iphone-6.9]="iPhone 17 Pro Max"
DEVICES[ipad-13]="iPad Pro 13-inch (M5)"

rm -rf "$RESULT_ROOT"
mkdir -p "$RESULT_ROOT" "$OUTPUT_ROOT"

for device_class device_name in ${(kv)DEVICES}; do
    result_bundle="$RESULT_ROOT/$device_class.xcresult"
    export_dir="$RESULT_ROOT/$device_class-export"
    final_dir="$OUTPUT_ROOT/$device_class"

    rm -rf "$result_bundle" "$export_dir" "$final_dir"
    mkdir -p "$export_dir" "$final_dir"

    # A recently completed UI-test session can leave SpringBoard briefly busy.
    # Starting each device class from a clean shutdown avoids a flaky runner
    # preflight failure when captures are regenerated back-to-back.
    xcrun simctl shutdown "$device_name" 2>/dev/null || true

    xcodebuild test -quiet \
        -project "$ROOT/TeoPateo.xcodeproj" \
        -scheme TeoPateo \
        -destination "platform=iOS Simulator,name=$device_name,OS=latest" \
        -only-testing:TeoPateoUITests/TeoPateoUITests/testCaptureAppStoreScreenshots \
        -resultBundlePath "$result_bundle"

    xcrun xcresulttool export attachments \
        --path "$result_bundle" \
        --output-path "$export_dir"

    jq -r '.[] | .attachments[] | [.exportedFileName, (.suggestedHumanReadableName | sub("_0_[A-F0-9-]+\\.png$"; ".png"))] | @tsv' \
        "$export_dir/manifest.json" | while IFS=$'\t' read -r exported_name final_name; do
        cp "$export_dir/$exported_name" "$final_dir/$final_name"
    done

    # On iPadOS 26, repeatedly terminating and relaunching an app inside one UI
    # test can occasionally restore one launch as a floating window. Capture the
    # tall Insights screen in its own fresh test session to guarantee a full-size
    # product-page image with no window-manager background.
    if [[ "$device_class" == "ipad-13" ]]; then
        insights_result="$RESULT_ROOT/$device_class-insights.xcresult"
        insights_export="$RESULT_ROOT/$device_class-insights-export"
        rm -rf "$insights_result" "$insights_export"
        xcrun simctl shutdown "$device_name" 2>/dev/null || true

        xcodebuild test -quiet \
            -project "$ROOT/TeoPateo.xcodeproj" \
            -scheme TeoPateo \
            -destination "platform=iOS Simulator,name=$device_name,OS=latest" \
            -only-testing:TeoPateoUITests/TeoPateoUITests/testCaptureAppStoreInsightsScreenshot \
            -resultBundlePath "$insights_result"

        xcrun xcresulttool export attachments \
            --path "$insights_result" \
            --output-path "$insights_export"
        insights_file=$(find "$insights_export" -type f -name '*.png' -print -quit)
        cp "$insights_file" "$final_dir/04-insights.png"
    fi

    count=$(find "$final_dir" -type f -name '*.png' | wc -l | tr -d ' ')
    if [[ "$count" -ne 5 ]]; then
        print -u2 "Expected 5 screenshots for $device_class, found $count"
        exit 1
    fi
done

print "Raw App Store screenshots exported to $OUTPUT_ROOT"
