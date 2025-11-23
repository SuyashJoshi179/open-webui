# iOS App Setup and Build Guide

## Prerequisites

### Required Software
- macOS Sonoma 14.0 or later
- Xcode 16.0 or later
- iOS 18.0 SDK
- Swift 5.9 or later

### Required Hardware for Testing
- iPhone 15 Pro or later, OR
- iPad with M1 chip or later
- Apple Silicon Mac (M1/M2/M3/M4) for development

### Apple Developer Account
- Free account: For simulator and personal device testing
- Paid account: For App Store distribution and TestFlight

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/open-webui/open-webui.git
cd open-webui/ios
```

### 2. Install Dependencies

The project uses Swift Package Manager for dependencies. Xcode will automatically resolve them when you first open the project.

Dependencies include:
- Alamofire (Networking)
- Starscream (WebSocket)
- MarkdownUI (Markdown rendering)
- KeychainAccess (Secure storage)

### 3. Configure Backend URL

Edit `OpenWebUI/App/AppConfig.swift`:

```swift
static var backendURL: String {
    #if DEBUG
    return "http://localhost:8080"  // For local development
    #else
    return "https://your-production-server.com"  // For production
    #endif
}
```

### 4. Open in Xcode

Since we don't have a traditional Xcode project file yet, you need to create one:

```bash
cd ios
# Option 1: Create Xcode project from Package.swift
swift package generate-xcodeproj

# Option 2: Open Package.swift directly in Xcode (recommended)
open Package.swift
```

## Building the App

### Using Xcode GUI

1. **Open the project**:
   - File > Open
   - Navigate to `ios/Package.swift`
   - Click Open

2. **Select Target Device**:
   - Choose a physical device (iPhone 15 Pro or later)
   - Or select a simulator (Note: Apple Intelligence won't work in simulator)

3. **Configure Signing**:
   - Select the OpenWebUI target
   - Go to "Signing & Capabilities"
   - Select your team
   - Xcode will automatically manage provisioning

4. **Build and Run**:
   - Press ⌘R or click the Play button
   - Wait for dependencies to resolve
   - App will build and launch

### Using Command Line

```bash
# Build for simulator
xcodebuild -scheme OpenWebUI \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build

# Build for device
xcodebuild -scheme OpenWebUI \
  -destination 'platform=iOS,name=Your iPhone' \
  build

# Run tests
xcodebuild test -scheme OpenWebUI \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Configuring Apple Intelligence

### 1. Enable on Device

Before the app can use Apple Intelligence:

1. **On your iPhone/iPad**:
   - Settings > Apple Intelligence & Siri
   - Toggle "Apple Intelligence" ON
   - Agree to terms if prompted

2. **Download Model**:
   - The model will begin downloading automatically
   - This can take 10-30 minutes depending on connection
   - Model size is approximately 3-4 GB

3. **Verify Installation**:
   - Settings > General > iPhone Storage
   - Look for "Apple Intelligence" to see model status

### 2. Test in App

1. Launch the app
2. Sign in or create account
3. Create a new chat
4. Select "Apple Intelligence" as the model
5. Send a test message
6. You should see responses generated on-device

### Status Indicators

The app shows the model status:
- ✅ "Apple Intelligence is ready" - Model available
- ⏳ "Model is downloading..." - Still downloading
- ❌ "Not enabled" - Go to Settings to enable
- ❌ "Device not eligible" - Upgrade to compatible device

## Project Structure

```
ios/
├── OpenWebUI/
│   ├── App/
│   │   ├── OpenWebUIApp.swift       # App entry point
│   │   └── AppConfig.swift          # Configuration
│   ├── Models/
│   │   ├── APIModels.swift          # API data models
│   │   └── ChatModels.swift         # Chat models
│   ├── Services/
│   │   ├── APIClient.swift          # Backend API
│   │   ├── AuthService.swift        # Authentication
│   │   ├── OpenAIService.swift      # OpenAI integration
│   │   ├── OllamaService.swift      # Ollama integration
│   │   ├── MLXService.swift         # Apple Intelligence
│   │   ├── RAGService.swift         # RAG support
│   │   └── ToolService.swift        # Tool calling
│   ├── ViewModels/
│   │   └── (View model classes)
│   ├── Views/
│   │   ├── Chat/                    # Chat UI
│   │   ├── Models/                  # Model management
│   │   ├── Documents/               # RAG documents
│   │   ├── Settings/                # Settings
│   │   ├── LoginView.swift          # Authentication
│   │   └── MainTabView.swift        # Tab navigation
│   ├── Utilities/
│   │   └── KeychainHelper.swift     # Secure storage
│   └── Resources/
│       └── Info.plist               # App configuration
├── Package.swift                     # Dependencies
└── README.md                         # Documentation
```

## Common Build Issues

### Issue 1: "No such module 'FoundationModels'"

**Solution**: 
- Ensure you're running iOS 18.0 SDK or later
- Update Xcode to version 16.0 or later
- Clean build folder: Product > Clean Build Folder (⇧⌘K)

### Issue 2: Code Signing Error

**Solution**:
- Ensure you have a valid development team selected
- Try automatic signing first
- If using manual signing, ensure provisioning profile is valid

### Issue 3: Dependencies Not Resolving

**Solution**:
```bash
# Clear Swift Package Manager cache
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData

# In Xcode: File > Packages > Reset Package Caches
```

### Issue 4: "Apple Intelligence Not Available"

**Possible Causes**:
1. Testing on simulator (not supported)
2. iOS version < 18.0
3. Device not eligible (older models)
4. Apple Intelligence not enabled in Settings
5. Model still downloading

**Solution**:
- Test on physical iPhone 15 Pro or later
- Check Settings > Apple Intelligence & Siri
- Wait for model download to complete

## Development Workflow

### 1. Feature Development

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes
# ...

# Test thoroughly
xcodebuild test -scheme OpenWebUI

# Commit and push
git commit -am "Add new feature"
git push origin feature/new-feature
```

### 2. Testing

```swift
// Unit tests in OpenWebUITests/
import XCTest
@testable import OpenWebUI

class APIClientTests: XCTestCase {
    func testRequestBuilding() {
        // Test API client
    }
}
```

### 3. Debugging

Enable detailed logging in `AppConfig.swift`:

```swift
#if DEBUG
static let enableLogging = true
static let enableNetworkLogging = true
#endif
```

View logs in Xcode console:
- 📡 Network requests
- 📥 API responses  
- ✅ Success messages
- ❌ Error details

## Running with Backend

### Local Backend Setup

1. **Start the backend** (in repository root):
```bash
# Using Docker
docker-compose up

# Or using Python
cd backend
python -m uvicorn open_webui.main:app --reload --host 0.0.0.0 --port 8080
```

2. **Configure iOS app**:
   - For physical device on same network: Use Mac's IP address
   - For simulator: Use `http://localhost:8080`

3. **Test connection**:
   - Open app
   - Try to sign in
   - Check network logs in Xcode console

### Production Backend

Update `AppConfig.swift` with production URL:
```swift
static var backendURL: String {
    return "https://your-server.com"
}
```

## Distribution

### TestFlight (Beta Testing)

1. **Archive the app**:
   - Product > Archive
   - Wait for build to complete
   - Organizer window opens

2. **Upload to App Store Connect**:
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Upload

3. **Configure in App Store Connect**:
   - Add test information
   - Add testers
   - Submit for review

### App Store Release

1. Complete TestFlight testing
2. Prepare App Store listing
3. Submit for App Store review
4. Respond to feedback if needed
5. Release when approved

## Performance Tips

### 1. Optimize Build Times

```bash
# Use build settings
# In Xcode: Build Settings > Build Options
# Set "Compilation Mode" to "Incremental" for debug
```

### 2. Monitor Performance

```swift
// Add performance instrumentation
import os.signpost

let log = OSLog(subsystem: "com.openwebui.ios", category: "Performance")
os_signpost(.begin, log: log, name: "API Call")
// ... API call ...
os_signpost(.end, log: log, name: "API Call")
```

### 3. Profile with Instruments

- Product > Profile (⌘I)
- Choose instrument (Time Profiler, Allocations, etc.)
- Record while using app
- Analyze hotspots

## Next Steps

1. ✅ Complete setup above
2. 📱 Test on physical device
3. 🧪 Run included tests
4. 🎨 Customize UI as needed
5. 🚀 Deploy to TestFlight
6. 📝 Gather feedback
7. 🏪 Submit to App Store

## Support

For help with setup:
- Check [README.md](README.md) for overview
- Review [APPLE_INTELLIGENCE_INTEGRATION.md](APPLE_INTELLIGENCE_INTEGRATION.md) for AI details
- Open issue on GitHub with "ios" label
- Include Xcode version, iOS version, and device model

## Additional Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [FoundationModels Framework](https://developer.apple.com/documentation/foundationmodels)
- [Open WebUI Documentation](https://docs.openwebui.com/)
