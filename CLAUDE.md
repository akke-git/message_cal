# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MessageCal is a Flutter app that receives shared text messages from messaging apps and converts them into Google Calendar events. The app uses Android's sharing intent system to receive text data and provides AI-powered schedule extraction and categorization.

## Key Development Commands

### IMPORTANT: Terminal Commands
- **This project runs on Windows environment**
- **Claude should NOT execute terminal/bash commands**
- **User will manually run all Flutter commands in Windows terminal**
- Commands listed below are for reference only

### Flutter Commands (User executes manually)
- `flutter run` - Run the app in debug mode
- `flutter build apk` - Build APK for Android
- `flutter build appbundle` - Build Android App Bundle for Play Store
- `flutter test` - Run unit tests
- `flutter analyze` - Run static analysis
- `flutter clean` - Clean build cache
- `flutter pub get` - Install dependencies
- `flutter pub upgrade` - Upgrade dependencies

### Android Development
- Use Android Studio or VS Code with Flutter extension
- Test sharing functionality on physical device or emulator
- After manifest changes, run `flutter clean` and rebuild completely
- Use `adb logcat` to debug Android Intent issues

## Architecture

### App Structure
- **Entry Point**: `lib/main.dart` - App initialization with Material Design 3
- **Navigation**: `lib/layout/main_layout.dart` - Bottom navigation with 3 tabs (Home, Calendar, Settings)
- **Core Screens**:
  - `lib/screens/splash_screen.dart` - App startup screen
  - `lib/screens/home_screen.dart` - Main dashboard with sharing intent listener
  - `lib/screens/share_receiver_screen.dart` - Processes shared text and creates calendar events
  - `lib/screens/calendar_screen.dart` - Calendar view with real Google Calendar events
  - `lib/screens/settings_screen.dart` - App settings
- **Services**: 
  - `lib/services/auth_service.dart` - Google authentication for calendar access
  - `lib/services/calendar_service.dart` - Google Calendar API integration

### Key Features
1. **Intent Sharing**: Uses `receive_sharing_intent` package to receive text from other apps
2. **Google Calendar Integration**: OAuth 2.0 authentication with Calendar API access
3. **AI Text Processing**: Extracts schedule information from shared messages (planned)
4. **Category Classification**: Automatically categorizes events (planned)

### Android Configuration
- **Manifest**: `android/app/src/main/AndroidManifest.xml` configured for text sharing
- **Intent Filters**: Supports `SEND` and `SEND_MULTIPLE` actions for `text/*` MIME types
- **Launch Mode**: `singleTask` to handle multiple share intents properly

## Dependencies

### Key Packages
- `receive_sharing_intent: ^1.4.5` - Handles Android sharing intents
- `google_sign_in: ^6.0.0` - Google authentication
- `googleapis: ^11.0.0` - Google Calendar API client
- `googleapis_auth: ^1.4.1` - Google APIs authentication
- `shared_preferences: ^2.0.0` - Local storage
- `sqflite: ^2.0.0` - Local database
- `intl: ^0.18.0` - Internationalization
- `url_launcher: ^6.0.0` - URL launching

## Development Notes

### Current Status
- Basic project structure completed ✅
- Android sharing functionality implemented ✅
- Google Calendar API integration implemented ✅
- CalendarService for API interactions created ✅
- AuthService with proper scopes implemented ✅
- ShareReceiverScreen with Calendar API integration ✅
- CalendarScreen with real event display ✅
- Android permissions and network settings added ✅
- Text analysis and AI categorization features are planned

### Testing Sharing Functionality
1. Install app on device/emulator
2. Open messaging app (KakaoTalk, SMS, etc.)
3. Select text message and use "Share" option
4. MessageCal should appear in share menu
5. If not appearing, check Android manifest and rebuild completely

### Common Issues
- Sharing intent may not work in emulator - test on physical device
- After manifest changes, always run `flutter clean` before rebuilding
- Check `adb logcat` for intent-related debugging information

## Code Style
- Uses Material Design 3 with blue color scheme
- Korean language support for UI text
- Follows Flutter/Dart naming conventions
- Uses `const` constructors where possible
- Includes TODO comments for planned features

## Next Development Steps
1. ✅ ~~Fix Android sharing functionality~~
2. ✅ ~~Implement Google Calendar API integration~~
3. Add Google login functionality to Settings screen
4. Add AI-powered message parsing enhancement
5. Implement automatic categorization improvement
6. Add dashboard with schedule overview enhancement
7. Comprehensive testing on physical device

## Google Calendar API Integration Status
- **OAuth 2.0 Setup**: Ready (requires Google Cloud Console configuration)
- **CalendarService**: Implemented with create/read events functionality
- **AuthService**: Enhanced with proper calendar scopes
- **ShareReceiverScreen**: Integrated with Calendar API
- **CalendarScreen**: Displays real Google Calendar events
- **Android Permissions**: Added for network access