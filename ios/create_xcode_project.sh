#!/bin/bash

# Create iOS App Xcode Project
# This script creates an Xcode project that wraps the OpenWebUI Swift Package

cd "$(dirname "$0")"

echo "🚀 Creating OpenWebUI iOS App Project..."

# Use swift package generate-xcodeproj command
swift package generate-xcodeproj

if [ $? -eq 0 ]; then
    echo "✅ Xcode project generated successfully!"
    echo "📦 Opening project in Xcode..."
    open OpenWebUI.xcodeproj
else
    echo "❌ Failed to generate Xcode project"
    echo "Trying alternative method..."
    
    # Alternative: Use xcodebuild to create project
    cat > project.yml <<EOF
name: OpenWebUIApp
options:
  bundleIdPrefix: com.openwebui
  deploymentTarget:
    iOS: 18.0
settings:
  SWIFT_VERSION: 6.0
targets:
  OpenWebUIApp:
    type: application
    platform: iOS
    deploymentTarget: 18.0
    sources:
      - OpenWebUIApp
    dependencies:
      - package: OpenWebUI
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.openwebui.app
      DEVELOPMENT_TEAM: ""
      CODE_SIGN_STYLE: Automatic
      INFOPLIST_FILE: OpenWebUIApp/Info.plist
    scheme:
      testTargets:
        - OpenWebUITests
packages:
  OpenWebUI:
    path: .
EOF
    
    if command -v xcodegen &> /dev/null; then
        xcodegen generate
        echo "✅ Project created with xcodegen!"
        open OpenWebUIApp.xcodeproj
    else
        echo "⚠️  xcodegen not found. Install it with: brew install xcodegen"
        echo "Or manually create an iOS App project in Xcode and add the package dependency."
    fi
fi
