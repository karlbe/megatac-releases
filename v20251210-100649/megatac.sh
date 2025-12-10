#!/bin/bash

# MegaTac Game Launcher for Linux
# Automatically downloads OpenJDK 25 JRE and the game JAR if needed, then launches the game
# Uses Eclipse Temurin (based on OpenJDK) from Adoptium

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
MEGATAC_DIR="$HOME/.megatac"
JRE_DIR="$MEGATAC_DIR/jre"  # OpenJDK JRE (not JDK)
JAR_NAME="megatac-1.0.0.jar"
JAR_PATH="$MEGATAC_DIR/$JAR_NAME"
GITHUB_REPO="karlbe/megatac-releases"
GITHUB_API="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
ADOPTIUM_API="https://api.adoptium.net/v3/binary/latest/25/ga"  # OpenJDK 25 from Adoptium

# Ensure directories exist
mkdir -p "$MEGATAC_DIR"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Java is available and get its version
get_java_version() {
    if command -v java &> /dev/null; then
        java -version 2>&1 | grep -oP 'version "\K[^"]+' || java -version 2>&1 | head -1
    else
        echo "none"
    fi
}

# Function to check if Java version is 25+
is_java_25_or_later() {
    local version="$1"
    
    # Extract major version number
    local major=$(echo "$version" | grep -oP '^\d+' || echo "0")
    
    # Reject Java 1.x (old format)
    if [[ "$version" =~ ^1\. ]]; then
        return 1
    fi
    
    # Check if major version is >= 25
    if [[ "$major" -ge 25 ]]; then
        return 0
    fi
    
    return 1
}

# Function to download OpenJDK 25 JRE from Adoptium (Eclipse Temurin)
download_java() {
    log_info "Downloading OpenJDK 25 JRE from Adoptium..."
    
    # Determine OS and architecture
    local os_type=$(uname -s)
    local arch=$(uname -m)
    local adoptium_os=""
    local adoptium_arch=""
    local archive_ext=""
    
    case "$os_type" in
        Linux)
            adoptium_os="linux"
            case "$arch" in
                x86_64)
                    adoptium_arch="x64"
                    ;;
                aarch64)
                    adoptium_arch="aarch64"
                    ;;
                *)
                    log_error "Unsupported architecture: $arch"
                    return 1
                    ;;
            esac
            archive_ext="tar.gz"
            ;;
        Darwin)
            adoptium_os="mac"
            case "$arch" in
                x86_64)
                    adoptium_arch="x64"
                    ;;
                arm64)
                    adoptium_arch="aarch64"
                    ;;
                *)
                    log_error "Unsupported architecture: $arch"
                    return 1
                    ;;
            esac
            archive_ext="tar.gz"
            ;;
    local temp_file=$(mktemp)
    
    if command -v curl &> /dev/null; then
        curl -L -o "$temp_file" "$java_url" 2>/dev/null || {
            log_error "Failed to download OpenJDK JRE from $java_url"
            rm -f "$temp_file"
            return 1
        }
    elif command -v wget &> /dev/null; then
        wget -O "$temp_file" "$java_url" 2>/dev/null || {
            log_error "Failed to download OpenJDK JRE from $java_url"
            rm -f "$temp_file"
            return 1
        }
    else
        log_error "Neither curl nor wget found. Cannot download OpenJDK JRE."
        return 1
    fi
    
    mkdir -p "$JRE_DIR"
    tar -xzf "$temp_file" -C "$JRE_DIR" --strip-components=1
    rm -f "$temp_file"
    
    log_success "OpenJDK 25 JRE downloaded and extracted"
    return 0error "Neither curl nor wget found. Cannot download Java."
        return 1
    fi
    
    mkdir -p "$JAVA_DIR"
    tar -xzf "$temp_file" -C "$JAVA_DIR" --strip-components=1
    rm -f "$temp_file"
    
    log_success "Java 25 downloaded and extracted"
    return 0
}

# Function to download the game JAR
download_jar() {
    log_info "Downloading MegaTac JAR from GitHub..."
    
    # Get the download URL from GitHub API
    local download_url=$(curl -s "$GITHUB_API" | grep -o '"browser_download_url": "[^"]*megatac-1.0.0.jar"' | cut -d'"' -f4)
    
    if [[ -z "$download_url" ]]; then
        log_error "Could not find JAR download URL on GitHub"
        return 1
    fi
    
    local temp_file=$(mktemp)
    
    if command -v curl &> /dev/null; then
        curl -L -o "$temp_file" "$download_url" 2>/dev/null || {
            log_error "Failed to download JAR from GitHub"
            rm -f "$temp_file"
            return 1
        }
    elif command -v wget &> /dev/null; then
        wget -O "$temp_file" "$download_url" 2>/dev/null || {
            log_error "Failed to download JAR from GitHub"
            rm -f "$temp_file"
            return 1
        }
    else
        log_error "Neither curl nor wget found. Cannot download JAR."
        return 1
    fi
    
    mv "$temp_file" "$JAR_PATH"
    log_success "MegaTac JAR downloaded"
    return 0
}

# Check for OpenJDK 25
log_info "Checking for OpenJDK 25 JRE..."
JAVA_VERSION=$(get_java_version)

if is_java_25_or_later "$JAVA_VERSION"; then
    log_success "Found OpenJDK: $JAVA_VERSION"
    JAVA_BIN="java"
else
    log_warning "OpenJDK 25+ not found (found: $JAVA_VERSION). Attempting to use local OpenJDK JRE..."
    
    if [[ -f "$JRE_DIR/bin/java" ]]; then
        log_success "Using locally installed OpenJDK JRE"
        JAVA_BIN="$JRE_DIR/bin/java"
    else
        log_info "Downloading OpenJDK 25 JRE from Adoptium..."
        if download_java; then
            JAVA_BIN="$JRE_DIR/bin/java"
        else
            log_error "Failed to set up OpenJDK 25 JRE. Please install it manually."
            exit 1
        fi
    fi
fi

# Check for JAR
if [[ ! -f "$JAR_PATH" ]]; then
    log_warning "MegaTac JAR not found at $JAR_PATH"
    if download_jar; then
        log_success "JAR downloaded"
    else
        log_error "Failed to download JAR. Please download it manually."
        exit 1
    fi
else
    log_success "Found MegaTac JAR"
fi

# Launch the game
log_info "Launching MegaTac..."
"$JAVA_BIN" -jar "$JAR_PATH" "$@"
