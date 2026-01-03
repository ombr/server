#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    print_warn "Not running as root. Attempting to use sudo..."
    SUDO="sudo"
else
    SUDO=""
fi

print_info "Starting VPS setup..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
else
    print_error "Cannot detect OS. Exiting."
    exit 1
fi

print_info "Detected OS: $OS $OS_VERSION"

# Update package list
print_info "Updating package list..."
$SUDO apt-get update -y

# Install basic dependencies
print_info "Installing basic dependencies (git, curl, wget, ca-certificates, gnupg, lsb-release)..."
$SUDO apt-get install -y \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    print_info "Docker not found. Installing Docker..."
    
    # Add Docker's official GPG key
    $SUDO install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
      $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list again
    $SUDO apt-get update -y
    
    # Install Docker Engine
    $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    print_info "Docker installed successfully"
else
    print_info "Docker is already installed"
fi

# Install Docker Compose (standalone) if not already installed
if ! command -v docker-compose &> /dev/null; then
    print_info "Docker Compose (standalone) not found. Installing..."
    
    # Get latest version
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    $SUDO curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    $SUDO chmod +x /usr/local/bin/docker-compose
    
    print_info "Docker Compose installed successfully (version: $DOCKER_COMPOSE_VERSION)"
else
    print_info "Docker Compose is already installed"
fi

# Start Docker service
print_info "Starting Docker service..."
$SUDO systemctl enable docker
$SUDO systemctl start docker

# Add current user to docker group (if not root)
if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
    print_info "Adding current user to docker group..."
    $SUDO usermod -aG docker $USER
    print_warn "You may need to log out and back in for docker group changes to take effect"
fi

# Navigate to script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

print_info "Current directory: $SCRIPT_DIR"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found in current directory!"
    exit 1
fi

# Check if required files exist
print_info "Checking required files..."
REQUIRED_FILES=("Caddyfile" "frps.toml" "check.py")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        print_warn "Required file $file not found. Service may not work correctly."
    else
        print_info "Found $file"
    fi
done

# Start services with docker-compose
print_info "Starting services with docker-compose..."
if [ "$EUID" -eq 0 ]; then
    docker-compose up -d
else
    $SUDO docker-compose up -d
fi

# Wait a moment for services to start
sleep 3

# Check service status
print_info "Checking service status..."
if [ "$EUID" -eq 0 ]; then
    docker-compose ps
else
    $SUDO docker-compose ps
fi

print_info "Setup complete!"
print_info "Services are now running. You can check logs with: docker-compose logs -f"
print_info "To stop services: docker-compose down"
print_info "To restart services: docker-compose restart"

