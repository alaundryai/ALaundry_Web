#!/bin/bash
set -e

echo "🚀 Starting Flutter web build for Vercel..."

# Check if Flutter is already in PATH (Vercel or CI environment)
if ! command -v flutter &> /dev/null; then
    echo "📦 Flutter not found in PATH, installing..."
    
    # Install Flutter SDK
    FLUTTER_VERSION="3.24.0"
    FLUTTER_SDK_DIR="$HOME/flutter"
    
    if [ ! -d "$FLUTTER_SDK_DIR" ]; then
        echo "Downloading Flutter SDK..."
        cd $HOME
        git clone https://github.com/flutter/flutter.git -b stable --depth 1
    fi
    
    # Add Flutter to PATH
    export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
    
    # Accept Flutter licenses
    flutter doctor --android-licenses || true
fi

# Verify Flutter installation
echo "Flutter version:"
flutter --version

# Enable web support
flutter config --enable-web

# Get dependencies
echo "📚 Getting Flutter dependencies..."
flutter pub get

# Build for web with release mode
echo "🔨 Building Flutter web app..."
flutter build web --release --web-renderer canvaskit

echo "✅ Build complete! Output in build/web"
echo "📁 Build output contents:"
ls -la build/web/ | head -20
