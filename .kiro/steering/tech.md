# Technology Stack

## Frontend (Flutter)

- **Framework**: Flutter 3.7.2+ with Dart
- **State Management**: Provider pattern
- **Navigation**: go_router for declarative routing
- **Database**: SQLite via sqflite for local storage
- **HTTP Client**: http package for API communication
- **UI Components**: Material Design with custom theming
- **Charts**: fl_chart for analytics visualization
- **Localization**: flutter_localizations with custom AppLocalizations

### Key Dependencies
```yaml
# Core Flutter
flutter: sdk
flutter_localizations: sdk

# State & Navigation  
provider: ^6.1.1
go_router: ^12.1.3

# Database & Storage
sqflite: ^2.4.2
shared_preferences: ^2.2.3

# UI & Visualization
fl_chart: ^0.68.0
flutter_svg: ^2.0.9

# Utilities
http: ^1.1.0
intl: ^0.19.0
uuid: ^4.2.1
url_launcher: ^6.3.1
```

## Backend (Yandex Cloud Functions)

- **Runtime**: Python 3.9
- **Architecture**: Serverless functions with Yandex Cloud
- **Database**: Yandex Database (YDB) for persistent storage
- **Authentication**: JWT tokens with custom middleware
- **API Gateway**: Yandex API Gateway with OpenAPI 3.0 specification

### Backend Structure
- Individual Python functions for each API endpoint
- Shared JWT authentication module (`functions/shared/jwt_auth.py`)
- Environment-based configuration (API keys, database endpoints)

## Common Commands

### Flutter Development
```bash
# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Build for production
flutter build apk --release          # Android
flutter build ios --release          # iOS
flutter build macos --release        # macOS
flutter build windows --release      # Windows
flutter build linux --release        # Linux

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .
```

### Backend Deployment
```bash
# Set environment variables
source deploy_env.sh

# Deploy all functions
./deploy_all_updated_functions.sh

# Deploy individual function
yc serverless function version create \
  --function-name=function-name \
  --runtime=python39 \
  --entrypoint=index.handler \
  --source-path=functions/function-name/
```

### Development Workflow
```bash
# Clean and rebuild
flutter clean && flutter pub get

# Hot reload during development
flutter run --hot

# Generate code (if using code generation)
flutter packages pub run build_runner build

# Update dependencies
flutter pub upgrade
```

## Build System

- **Flutter**: Standard Flutter build system with pubspec.yaml
- **Backend**: Yandex Cloud CLI for function deployment
- **Assets**: Custom fonts (Inter family) and SVG icons
- **Platforms**: Multi-platform support (iOS, Android, macOS, Windows, Linux)

## Environment Configuration

### Required Environment Variables
- `API_KEY`: Yandex Cloud API authentication key
- `JWT_SECRET_KEY`: Secret for JWT token signing
- `YDB_ENDPOINT`: Yandex Database connection endpoint  
- `YDB_DATABASE`: Database path identifier

### Local Development
- Use `deploy_env.sh` for setting environment variables
- SQLite database for local data persistence
- Hot reload for rapid development iteration