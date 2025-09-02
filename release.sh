#!/bin/bash

# Release script for inapp-update Android app
# This script automates the release process for generating signed AAB files

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if keystore exists
check_keystore() {
    if [ ! -f "keystore.properties" ]; then
        print_error "keystore.properties not found!"
        print_error "Please create keystore.properties with your keystore details"
        exit 1
    fi
    
    # Check if keystore file exists
    source keystore.properties
    # Convert relative path to absolute path for checking
    if [[ "$storeFile" == ../* ]]; then
        # Remove ../ prefix and check from project root
        keystore_path="${storeFile#../}"
        if [ ! -f "$keystore_path" ]; then
            print_error "Keystore file not found at: $keystore_path"
            print_error "Please ensure your keystore file exists"
            exit 1
        fi
    else
        if [ ! -f "$storeFile" ]; then
            print_error "Keystore file not found at: $storeFile"
            print_error "Please ensure your keystore file exists"
            exit 1
        fi
    fi
    
    print_success "Keystore configuration found"
}

# Function to clean project
clean_project() {
    print_status "Cleaning project..."
    ./gradlew clean
    print_success "Project cleaned"
}

# Function to copy AAB to release folder
copy_to_release_folder() {
    print_status "Copying AAB files to release folder..."
    
    # Create release directory if it doesn't exist
    mkdir -p app/release
    
    # Get version information from build.gradle.kts
    local version_name=$(grep 'versionName = "' app/build.gradle.kts | sed 's/.*versionName = "\(.*\)".*/\1/')
    local version_code=$(grep 'versionCode = ' app/build.gradle.kts | sed 's/.*versionCode = \([0-9]*\).*/\1/')
    
    # Create filename with version info
    local release_filename="inapp-update-v${version_name}-${version_code}.aab"
    local debug_filename="inapp-update-debug-v${version_name}-${version_code}.aab"
    
    print_status "Version: $version_name (Code: $version_code)"
    
    # Copy release AAB with versioned filename
    if [ -f "app/build/outputs/bundle/release/app-release.aab" ]; then
        cp "app/build/outputs/bundle/release/app-release.aab" "app/release/$release_filename"
        print_success "Release AAB copied to app/release/$release_filename"
    else
        print_error "Release AAB not found in build outputs"
        return 1
    fi
    
    # Copy debug AAB if it exists with versioned filename
    if [ -f "app/build/outputs/bundle/debug/app-debug.aab" ]; then
        cp "app/build/outputs/bundle/debug/app-debug.aab" "app/release/$debug_filename"
        print_success "Debug AAB copied to app/release/$debug_filename"
    fi
}

# Function to build release AAB
build_release() {
    print_status "Building release AAB..."
    ./gradlew bundleRelease
    print_success "Release AAB built successfully"
    
    # Copy to release folder
    copy_to_release_folder
}

# Function to build debug AAB (for testing)
build_debug() {
    print_status "Building debug AAB..."
    ./gradlew bundleDebug
    print_success "Debug AAB built successfully"
    
    # Copy to release folder
    copy_to_release_folder
}

# Function to show AAB location
show_output() {
    print_status "AAB files generated:"
    
    # Get version information for display
    local version_name=$(grep 'versionName = "' app/build.gradle.kts | sed 's/.*versionName = "\(.*\)".*/\1/')
    local version_code=$(grep 'versionCode = ' app/build.gradle.kts | sed 's/.*versionCode = \([0-9]*\).*/\1/')
    
    local release_filename="inapp-update-v${version_name}-${version_code}.aab"
    local debug_filename="inapp-update-debug-v${version_name}-${version_code}.aab"
    
    echo "Release AAB: app/release/$release_filename"
    echo "Debug AAB: app/release/$debug_filename"
    
    # Check if files exist
    if [ -f "app/release/$release_filename" ]; then
        print_success "Release AAB exists"
        ls -lh "app/release/$release_filename"
    fi
    
    if [ -f "app/release/$debug_filename" ]; then
        print_success "Debug AAB exists"
        ls -lh "app/release/$debug_filename"
    fi
}

# Function to show current version info
show_version() {
    print_status "Current app version:"
    grep -E "versionCode|versionName" app/build.gradle.kts | head -2
}

# Function to bump version
bump_version() {
    local version_type=$1
    
    if [ -z "$version_type" ]; then
        print_error "Please specify version type: patch, minor, or major"
        exit 1
    fi
    
    print_status "Bumping $version_type version..."
    
    # Read current version
    current_version=$(grep 'versionName = "' app/build.gradle.kts | sed 's/.*versionName = "\(.*\)".*/\1/')
    current_code=$(grep 'versionCode = ' app/build.gradle.kts | sed 's/.*versionCode = \([0-9]*\).*/\1/')
    
    print_status "Current version: $current_version (code: $current_code)"
    
    # Parse version components
    IFS='.' read -ra VERSION_PARTS <<< "$current_version"
    major=${VERSION_PARTS[0]}
    minor=${VERSION_PARTS[1]}
    patch=${VERSION_PARTS[2]}
    
    case $version_type in
        "patch")
            patch=$((patch + 1))
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        *)
            print_error "Invalid version type. Use: patch, minor, or major"
            exit 1
            ;;
    esac
    
    new_version="$major.$minor.$patch"
    new_code=$((current_code + 1))
    
    print_status "New version: $new_version (code: $new_code)"
    
    # Update build.gradle.kts
    sed -i.bak "s/versionCode = $current_code/versionCode = $new_code/" app/build.gradle.kts
    sed -i.bak "s/versionName = \"$current_version\"/versionName = \"$new_version\"/" app/build.gradle.kts
    
    # Remove backup files
    rm -f app/build.gradle.kts.bak
    
    print_success "Version bumped to $new_version (code: $new_code)"
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  clean           Clean the project"
    echo "  build           Build release AAB"
    echo "  build-debug     Build debug AAB"
    echo "  release         Clean, build release AAB, and show output"
    echo "  version         Show current version info"
    echo "  bump-patch      Bump patch version (1.2.3 -> 1.2.4)"
    echo "  bump-minor      Bump minor version (1.2.3 -> 1.3.0)"
    echo "  bump-major      Bump major version (1.2.3 -> 2.0.0)"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 release          # Full release process"
    echo "  $0 bump-patch       # Bump patch version"
    echo "  $0 build            # Just build release AAB"
}

# Main script logic
case "${1:-help}" in
    "clean")
        clean_project
        ;;
    "build")
        check_keystore
        build_release
        show_output
        ;;
    "build-debug")
        build_debug
        show_output
        ;;
    "release")
        check_keystore
        clean_project
        build_release
        show_output
        ;;
    "version")
        show_version
        ;;
    "bump-patch")
        bump_version "patch"
        ;;
    "bump-minor")
        bump_version "minor"
        ;;
    "bump-major")
        bump_version "major"
        ;;
    "help"|*)
        show_help
        ;;
esac
