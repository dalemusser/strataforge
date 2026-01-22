#!/bin/bash
#
# StrataForge Project Renaming Script
# ====================================
# This script renames a forked copy of strataforge to a new project name.
#
# Usage:
#   ./scripts/rename-project.sh <new-name> [github-username]
#
# Examples:
#   ./scripts/rename-project.sh stratalog
#   ./scripts/rename-project.sh stratasave myusername
#
# What it does:
#   1. Renames cmd/strataforge directory to cmd/<new-name>
#   2. Updates go.mod module path
#   3. Updates all Go import paths
#   4. Updates environment variable prefix (STRATAFORGE_ -> NEWNAME_)
#   5. Updates config files (database name, session name, etc.)
#   6. Updates Makefile, Dockerfile, docker-compose.yml
#   7. Updates template fallback names
#   8. Updates documentation references
#
# IMPORTANT: Run this script from the project root directory AFTER forking.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Validate arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <new-project-name> [github-username]"
    echo ""
    echo "Examples:"
    echo "  $0 stratalog"
    echo "  $0 stratasave myusername"
    echo ""
    echo "The new project name should be lowercase with no spaces."
    exit 1
fi

NEW_NAME="$1"
NEW_NAME_LOWER=$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]')
NEW_NAME_UPPER=$(echo "$NEW_NAME" | tr '[:lower:]' '[:upper:]')
NEW_NAME_TITLE=$(echo "$NEW_NAME" | sed 's/\b\(.\)/\u\1/g')  # Title case

GITHUB_USER="${2:-dalemusser}"

OLD_NAME="strataforge"
OLD_NAME_UPPER="STRATAFORGE"
OLD_NAME_TITLE="StrataForge"

# Validate new name (lowercase, alphanumeric, hyphens allowed)
if ! [[ "$NEW_NAME_LOWER" =~ ^[a-z][a-z0-9-]*$ ]]; then
    error "Invalid project name. Use lowercase letters, numbers, and hyphens only. Must start with a letter."
fi

# Check we're in the right directory
if [ ! -f "go.mod" ]; then
    error "go.mod not found. Please run this script from the project root directory."
fi

if [ ! -d "cmd/strataforge" ] && [ ! -d "cmd/$NEW_NAME_LOWER" ]; then
    error "cmd/strataforge directory not found. Has this project already been renamed?"
fi

echo ""
echo "=================================================="
echo "  StrataForge Project Renaming Script"
echo "=================================================="
echo ""
echo "Renaming project:"
echo "  From: strataforge (github.com/dalemusser/strataforge)"
echo "  To:   $NEW_NAME_LOWER (github.com/$GITHUB_USER/$NEW_NAME_LOWER)"
echo ""
echo "This will modify files in place. Make sure you have committed"
echo "or backed up any changes before proceeding."
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""

# ==============================================================================
# Step 1: Rename cmd directory
# ==============================================================================
info "Step 1: Renaming cmd directory..."

if [ -d "cmd/strataforge" ]; then
    mv "cmd/strataforge" "cmd/$NEW_NAME_LOWER"
    success "Renamed cmd/strataforge -> cmd/$NEW_NAME_LOWER"
else
    warn "cmd/strataforge not found, skipping directory rename"
fi

# ==============================================================================
# Step 2: Update go.mod module path
# ==============================================================================
info "Step 2: Updating go.mod module path..."

sed -i '' "s|github.com/dalemusser/strataforge|github.com/$GITHUB_USER/$NEW_NAME_LOWER|g" go.mod
success "Updated go.mod"

# ==============================================================================
# Step 3: Update all Go import paths
# ==============================================================================
info "Step 3: Updating Go import paths in all .go files..."

# Find all .go files and update imports
find . -name "*.go" -type f | while read -r file; do
    if grep -q "github.com/dalemusser/strataforge" "$file" 2>/dev/null; then
        sed -i '' "s|github.com/dalemusser/strataforge|github.com/$GITHUB_USER/$NEW_NAME_LOWER|g" "$file"
    fi
done
success "Updated import paths in Go files"

# ==============================================================================
# Step 4: Update environment variable prefix
# ==============================================================================
info "Step 4: Updating environment variable prefix..."

# config.go - EnvVarPrefix constant
if [ -f "internal/app/bootstrap/config.go" ]; then
    sed -i '' "s|EnvVarPrefix = \"STRATAFORGE\"|EnvVarPrefix = \"$NEW_NAME_UPPER\"|g" internal/app/bootstrap/config.go
    sed -i '' "s|Strataforge|$NEW_NAME_TITLE|g" internal/app/bootstrap/config.go
    success "Updated internal/app/bootstrap/config.go"
fi

# hooks.go - Name field
if [ -f "internal/app/bootstrap/hooks.go" ]; then
    sed -i '' "s|Name: \"strataforge\"|Name: \"$NEW_NAME_LOWER\"|g" internal/app/bootstrap/hooks.go
    success "Updated internal/app/bootstrap/hooks.go"
fi

# ==============================================================================
# Step 5: Update docker-compose.yml
# ==============================================================================
info "Step 5: Updating docker-compose.yml..."

if [ -f "docker-compose.yml" ]; then
    # Environment variables
    sed -i '' "s|STRATAFORGE_|${NEW_NAME_UPPER}_|g" docker-compose.yml
    # Container names
    sed -i '' "s|strataforge-|${NEW_NAME_LOWER}-|g" docker-compose.yml
    # Database name
    sed -i '' "s|MONGO_INITDB_DATABASE: strataforge|MONGO_INITDB_DATABASE: $NEW_NAME_LOWER|g" docker-compose.yml
    # Volume names
    sed -i '' "s|name: strataforge-|name: ${NEW_NAME_LOWER}-|g" docker-compose.yml
    # Comments and titles
    sed -i '' "s|StrataForge|$NEW_NAME_TITLE|g" docker-compose.yml
    sed -i '' "s|strataforge|$NEW_NAME_LOWER|g" docker-compose.yml
    success "Updated docker-compose.yml"
fi

# ==============================================================================
# Step 6: Update Dockerfile
# ==============================================================================
info "Step 6: Updating Dockerfile..."

if [ -f "Dockerfile" ]; then
    sed -i '' "s|/app/strataforge|/app/$NEW_NAME_LOWER|g" Dockerfile
    sed -i '' "s|./cmd/strataforge|./cmd/$NEW_NAME_LOWER|g" Dockerfile
    sed -i '' "s|\./strataforge|./$NEW_NAME_LOWER|g" Dockerfile
    success "Updated Dockerfile"
fi

# ==============================================================================
# Step 7: Update Makefile
# ==============================================================================
info "Step 7: Updating Makefile..."

if [ -f "Makefile" ]; then
    sed -i '' "s|bin/strataforge|bin/$NEW_NAME_LOWER|g" Makefile
    sed -i '' "s|./cmd/strataforge|./cmd/$NEW_NAME_LOWER|g" Makefile
    sed -i '' "s|strataforge:latest|$NEW_NAME_LOWER:latest|g" Makefile
    # Update help text
    sed -i '' "s|Strata Makefile|$NEW_NAME_TITLE Makefile|g" Makefile
    success "Updated Makefile"
fi

# ==============================================================================
# Step 8: Update config files
# ==============================================================================
info "Step 8: Updating config files..."

# config.toml
if [ -f "config.toml" ]; then
    sed -i '' "s|mongo_database = \"strataforge\"|mongo_database = \"$NEW_NAME_LOWER\"|g" config.toml
    sed -i '' "s|session_name = \"strataforge-session\"|session_name = \"$NEW_NAME_LOWER-session\"|g" config.toml
    sed -i '' "s|mail_from_name = \"Strataforge.*\"|mail_from_name = \"$NEW_NAME_TITLE\"|g" config.toml
    success "Updated config.toml"
fi

# config.example.toml
if [ -f "config.example.toml" ]; then
    sed -i '' "s|Strataforge Configuration|$NEW_NAME_TITLE Configuration|g" config.example.toml
    sed -i '' "s|STRATAFORGE_|${NEW_NAME_UPPER}_|g" config.example.toml
    sed -i '' "s|mongo_database = \"strataforge\"|mongo_database = \"$NEW_NAME_LOWER\"|g" config.example.toml
    sed -i '' "s|session_name = \"strataforge-session\"|session_name = \"$NEW_NAME_LOWER-session\"|g" config.example.toml
    sed -i '' "s|mail_from_name = \"Strataforge\"|mail_from_name = \"$NEW_NAME_TITLE\"|g" config.example.toml
    success "Updated config.example.toml"
fi

# ==============================================================================
# Step 9: Update templates
# ==============================================================================
info "Step 9: Updating template fallback names..."

# layout.gohtml
if [ -f "internal/app/resources/templates/layout.gohtml" ]; then
    sed -i '' "s|StrataForge|$NEW_NAME_TITLE|g" internal/app/resources/templates/layout.gohtml
    success "Updated layout.gohtml"
fi

# menu.gohtml
if [ -f "internal/app/resources/templates/menu.gohtml" ]; then
    sed -i '' "s|StrataForge|$NEW_NAME_TITLE|g" internal/app/resources/templates/menu.gohtml
    success "Updated menu.gohtml"
fi

# ==============================================================================
# Step 10: Update documentation
# ==============================================================================
info "Step 10: Updating documentation..."

# Find all markdown files
find ./docs -name "*.md" -type f 2>/dev/null | while read -r file; do
    if grep -q "strataforge\|StrataForge\|STRATAFORGE" "$file" 2>/dev/null; then
        sed -i '' "s|strataforge|$NEW_NAME_LOWER|g" "$file"
        sed -i '' "s|StrataForge|$NEW_NAME_TITLE|g" "$file"
        sed -i '' "s|STRATAFORGE|$NEW_NAME_UPPER|g" "$file"
    fi
done
success "Updated documentation files"

# CLAUDE.md
if [ -f "CLAUDE.md" ]; then
    sed -i '' "s|strataforge|$NEW_NAME_LOWER|g" CLAUDE.md
    sed -i '' "s|Strataforge|$NEW_NAME_TITLE|g" CLAUDE.md
    sed -i '' "s|StrataForge|$NEW_NAME_TITLE|g" CLAUDE.md
    sed -i '' "s|STRATAFORGE|$NEW_NAME_UPPER|g" CLAUDE.md
    success "Updated CLAUDE.md"
fi

# README.md (if exists)
if [ -f "README.md" ]; then
    sed -i '' "s|strataforge|$NEW_NAME_LOWER|g" README.md
    sed -i '' "s|StrataForge|$NEW_NAME_TITLE|g" README.md
    sed -i '' "s|STRATAFORGE|$NEW_NAME_UPPER|g" README.md
    sed -i '' "s|dalemusser|$GITHUB_USER|g" README.md
    success "Updated README.md"
fi

# ==============================================================================
# Step 11: Update .air.toml (if exists)
# ==============================================================================
if [ -f ".air.toml" ]; then
    info "Step 11: Updating .air.toml..."
    sed -i '' "s|cmd/strataforge|cmd/$NEW_NAME_LOWER|g" .air.toml
    sed -i '' "s|bin/strataforge|bin/$NEW_NAME_LOWER|g" .air.toml
    success "Updated .air.toml"
fi

# ==============================================================================
# Step 12: Run go mod tidy
# ==============================================================================
info "Step 12: Running go mod tidy..."

if go mod tidy 2>/dev/null; then
    success "go mod tidy completed"
else
    warn "go mod tidy failed - you may need to run it manually"
fi

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "=================================================="
echo "  Renaming Complete!"
echo "=================================================="
echo ""
echo "Your project has been renamed from 'strataforge' to '$NEW_NAME_LOWER'."
echo ""
echo "Changes made:"
echo "  - Renamed cmd/strataforge -> cmd/$NEW_NAME_LOWER"
echo "  - Updated go.mod module: github.com/$GITHUB_USER/$NEW_NAME_LOWER"
echo "  - Updated all Go import paths"
echo "  - Updated env var prefix: ${NEW_NAME_UPPER}_*"
echo "  - Updated config files (database: $NEW_NAME_LOWER, session: $NEW_NAME_LOWER-session)"
echo "  - Updated Docker files (containers: $NEW_NAME_LOWER-*)"
echo "  - Updated template fallback names"
echo "  - Updated documentation"
echo ""
echo "Next steps:"
echo "  1. Review the changes: git diff"
echo "  2. Build the project: make build"
echo "  3. Run tests: make test"
echo "  4. Update any remaining hardcoded references specific to your use case"
echo "  5. Commit the changes: git add -A && git commit -m 'Rename to $NEW_NAME_LOWER'"
echo ""
echo "If you need to set up the GitHub repository:"
echo "  git remote set-url origin git@github.com:$GITHUB_USER/$NEW_NAME_LOWER.git"
echo ""
