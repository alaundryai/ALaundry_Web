#!/bin/bash
set -e

# Store the project root directory
PROJECT_ROOT="$(pwd)"
echo "📁 Project root: $PROJECT_ROOT"

echo "🚀 Starting Flutter web build for Vercel..."

# Check if Flutter is already in PATH (Vercel or CI environment)
if ! command -v flutter &> /dev/null; then
    echo "📦 Flutter not found in PATH, installing..."
    
    # Install Flutter SDK
    FLUTTER_SDK_DIR="$HOME/flutter"
    
    if [ ! -d "$FLUTTER_SDK_DIR" ]; then
        echo "Downloading Flutter SDK..."
        cd $HOME
        git clone https://github.com/flutter/flutter.git -b stable --depth 1
        cd "$PROJECT_ROOT"
    fi
    
    # Add Flutter to PATH
    export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
    
    # Accept Flutter licenses (suppress warnings)
    yes | flutter doctor --android-licenses 2>/dev/null || true
fi

# Ensure we're in the project root
cd "$PROJECT_ROOT"
echo "📁 Current directory: $(pwd)"

# Verify Flutter installation
echo "Flutter version:"
flutter --version 2>&1 | grep -v "Woah!" || flutter --version

# Enable web support
flutter config --enable-web 2>&1 | grep -v "Woah!" || flutter config --enable-web

# Get dependencies
echo "📚 Getting Flutter dependencies..."
flutter pub get 2>&1 | grep -v "Woah!" || flutter pub get

# Build for web with release mode
echo "🔨 Building Flutter web app..."
flutter build web --release 2>&1 | grep -v "Woah!" || flutter build web --release

echo "✅ Build complete! Output in build/web"
echo "📁 Build output contents:"
ls -la build/web/ | head -20
