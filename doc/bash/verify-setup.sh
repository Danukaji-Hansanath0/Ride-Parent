#!/bin/bash

# Verification Script - Checks if all fixes are in place
# Run this to verify the project is properly configured

set -e

echo "🔍 Ride Platform - Configuration Verification"
echo "=============================================="
echo ""

ERRORS=0
WARNINGS=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check file exists
check_file() {
    local file=$1
    local description=$2
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅${NC} $description"
        return 0
    else
        echo -e "${RED}❌${NC} $description - File not found: $file"
        ((ERRORS++))
        return 1
    fi
}

# Function to check directory exists
check_dir() {
    local dir=$1
    local description=$2
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅${NC} $description"
        return 0
    else
        echo -e "${RED}❌${NC} $description - Directory not found: $dir"
        ((ERRORS++))
        return 1
    fi
}

# Function to check if file contains string
check_content() {
    local file=$1
    local pattern=$2
    local description=$3
    if [ -f "$file" ] && grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✅${NC} $description"
        return 0
    else
        echo -e "${RED}❌${NC} $description - Pattern not found in $file"
        ((ERRORS++))
        return 1
    fi
}

echo "📁 Checking Project Structure..."
echo "--------------------------------"
check_file "pom.xml" "Parent POM exists"
check_file "build-all-images.sh" "Build script exists"
check_file "quick-start.sh" "Quick start script exists"
check_file "docker-compose.yml" "Docker Compose file exists"
check_file "README.md" "Main README exists"
check_file "DEPLOYMENT_GUIDE.md" "Deployment guide exists"
check_file "FIXES_SUMMARY.md" "Fixes summary exists"
echo ""

echo "🐳 Checking Dockerfiles..."
echo "-------------------------"
SERVICES=(
    "auth-service"
    "booking-service"
    "gateway-service"
    "mail-service"
    "payment-service"
    "pricing-service"
    "user-service"
    "vehicle-service"
)

for service in "${SERVICES[@]}"; do
    check_file "$service/Dockerfile" "Dockerfile for $service"
    if [ -f "$service/Dockerfile" ]; then
        # Check if Dockerfile has correct structure
        if grep -q "COPY pom.xml" "$service/Dockerfile" && \
           grep -q "COPY $service" "$service/Dockerfile"; then
            echo -e "${GREEN}  ✓${NC} $service Dockerfile has correct structure"
        else
            echo -e "${RED}  ✗${NC} $service Dockerfile structure may be incorrect"
            ((WARNINGS++))
        fi

        # Check for correct JVM flag
        if grep -q "UseContainerSupport" "$service/Dockerfile"; then
            echo -e "${GREEN}  ✓${NC} $service has correct JVM flags"
        elif grep -q "UserContainerSupport" "$service/Dockerfile"; then
            echo -e "${YELLOW}  ⚠${NC} $service has deprecated JVM flag (UserContainerSupport)"
            ((WARNINGS++))
        fi
    fi
done
echo ""

echo "☸️  Checking Kubernetes Configurations..."
echo "---------------------------------------"
check_dir "k8s" "k8s directory exists"
check_dir "k8s/base" "k8s/base directory exists"
check_dir "k8s/components" "k8s/components directory exists"
check_dir "k8s/environments" "k8s/environments directory exists"
check_file "k8s/README.md" "k8s README exists"
check_file "k8s/environments/dev/kustomization.yaml" "Dev environment kustomization"
echo ""

echo "🔧 Checking Service Kustomizations..."
echo "------------------------------------"
for service in "${SERVICES[@]}"; do
    overlay_file="k8s/apps/$service/overlays/dev/kustomization.yaml"
    check_file "$overlay_file" "Kustomization for $service"

    if [ -f "$overlay_file" ]; then
        # Extract service prefix (e.g., "auth" from "auth-service")
        prefix="${service%-service}"

        # Check if it has namePrefix
        if grep -q "namePrefix: $prefix-" "$overlay_file"; then
            echo -e "${GREEN}  ✓${NC} $service has correct namePrefix ($prefix-)"
        else
            echo -e "${RED}  ✗${NC} $service missing or incorrect namePrefix"
            ((ERRORS++))
        fi

        # Check if config directory exists
        config_dir="k8s/apps/$service/overlays/dev/config"
        if [ -d "$config_dir" ]; then
            echo -e "${GREEN}  ✓${NC} $service config directory exists"
        else
            echo -e "${YELLOW}  ⚠${NC} $service config directory missing"
            ((WARNINGS++))
        fi
    fi
done
echo ""

echo "📝 Checking Build Script..."
echo "--------------------------"
if check_file "build-all-images.sh" "Build script exists"; then
    if grep -q "docker build -f" "build-all-images.sh"; then
        echo -e "${GREEN}  ✓${NC} Build script uses correct docker build command"
    else
        echo -e "${RED}  ✗${NC} Build script may need updating"
        ((WARNINGS++))
    fi
fi
echo ""

echo "📊 Summary"
echo "=========="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🎉 Perfect! All checks passed!${NC}"
    echo ""
    echo "Your Ride Platform is properly configured and ready to deploy!"
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./quick-start.sh"
    echo "  2. Or: docker-compose up --build"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Configuration OK with $WARNINGS warning(s)${NC}"
    echo ""
    echo "The project should work, but you may want to address the warnings above."
    echo ""
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the errors above before deploying."
    echo ""
    exit 1
fi

