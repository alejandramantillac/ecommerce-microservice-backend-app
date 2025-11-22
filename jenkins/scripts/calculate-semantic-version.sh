#!/bin/bash
# Script to calculate semantic version automatically based on commits
# Analyzes commits since last tag and determines MAJOR.MINOR.PATCH increment
# Usage: calculate-semantic-version.sh [base-version]

set -e

BASE_VERSION="${1:-0.0.0}"

# Parse base version
IFS='.' read -ra VERSION_PARTS <<< "$BASE_VERSION"
CURRENT_MAJOR="${VERSION_PARTS[0]:-0}"
CURRENT_MINOR="${VERSION_PARTS[1]:-0}"
CURRENT_PATCH="${VERSION_PARTS[2]:-0}"

echo "========================================="
echo "Calculating Semantic Version"
echo "Base Version: ${BASE_VERSION}"
echo "========================================="
echo ""

# Get the last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LAST_TAG" ]; then
    echo "No previous tags found, using base version: ${BASE_VERSION}"
    NEW_MAJOR=$CURRENT_MAJOR
    NEW_MINOR=$CURRENT_MINOR
    NEW_PATCH=$CURRENT_PATCH
else
    # Remove 'v' prefix if present
    LAST_TAG_VERSION="${LAST_TAG#v}"
    echo "Last tag: ${LAST_TAG} (version: ${LAST_TAG_VERSION})"
    
    # Parse last tag version
    IFS='.' read -ra LAST_PARTS <<< "$LAST_TAG_VERSION"
    LAST_MAJOR="${LAST_PARTS[0]:-0}"
    LAST_MINOR="${LAST_PARTS[1]:-0}"
    LAST_PATCH="${LAST_PARTS[2]:-0}"
    
    # Get commits since last tag
    COMMITS=$(git log ${LAST_TAG}..HEAD --pretty=format:"%s" 2>/dev/null || echo "")
    
    if [ -z "$COMMITS" ]; then
        echo "No new commits since last tag"
        NEW_MAJOR=$LAST_MAJOR
        NEW_MINOR=$LAST_MINOR
        NEW_PATCH=$LAST_PATCH
    else
        echo ""
        echo "Analyzing commits since ${LAST_TAG}..."
        
        # Initialize version increments
        INCREMENT_MAJOR=0
        INCREMENT_MINOR=0
        INCREMENT_PATCH=0
        
        # Analyze each commit
        while IFS= read -r commit; do
            if [ -z "$commit" ]; then
                continue
            fi
            
            commit_upper=$(echo "$commit" | tr '[:lower:]' '[:upper:]')
            
            # Check for BREAKING CHANGE (MAJOR) - highest priority
            # Patterns: "BREAKING CHANGE", "BREAKING:", "!:", or commit body contains breaking change
            if echo "$commit_upper" | grep -qE "(BREAKING CHANGE|BREAKING:|!:|BREAKING)"; then
                if [ $INCREMENT_MAJOR -eq 0 ]; then
                    echo "  → BREAKING CHANGE detected: ${commit:0:60}..."
                    INCREMENT_MAJOR=1
                    INCREMENT_MINOR=0
                    INCREMENT_PATCH=0
                fi
            # Check for feat: or "Add" or "Implement" (MINOR) - only if no MAJOR increment
            elif [ $INCREMENT_MAJOR -eq 0 ]; then
                if echo "$commit" | grep -qiE "(^feat(\(.+\))?:|^add |^implement |^new |^feature)"; then
                    if [ $INCREMENT_MINOR -eq 0 ]; then
                        echo "  → Feature detected: ${commit:0:60}..."
                        INCREMENT_MINOR=1
                        INCREMENT_PATCH=0
                    fi
                # Check for fix: or "Fix" or "Update" (PATCH) - only if no MINOR increment
                elif [ $INCREMENT_MINOR -eq 0 ] && echo "$commit" | grep -qiE "(^fix(\(.+\))?:|^fix |^update |^correct |^resolve )"; then
                    if [ $INCREMENT_PATCH -eq 0 ]; then
                        echo "  → Fix detected: ${commit:0:60}..."
                        INCREMENT_PATCH=1
                    fi
                # Check for other conventional commit types that might indicate PATCH
                elif [ $INCREMENT_MINOR -eq 0 ] && echo "$commit" | grep -qiE "^(perf|refactor|style|docs|chore|build|ci)(\(.+\))?:"; then
                    if [ $INCREMENT_PATCH -eq 0 ]; then
                        echo "  → Enhancement detected: ${commit:0:60}..."
                        INCREMENT_PATCH=1
                    fi
                fi
            fi
        done <<< "$COMMITS"
        
        # Calculate new version
        if [ $INCREMENT_MAJOR -eq 1 ]; then
            NEW_MAJOR=$((LAST_MAJOR + 1))
            NEW_MINOR=0
            NEW_PATCH=0
        elif [ $INCREMENT_MINOR -eq 1 ]; then
            NEW_MAJOR=$LAST_MAJOR
            NEW_MINOR=$((LAST_MINOR + 1))
            NEW_PATCH=0
        elif [ $INCREMENT_PATCH -eq 1 ]; then
            NEW_MAJOR=$LAST_MAJOR
            NEW_MINOR=$LAST_MINOR
            NEW_PATCH=$((LAST_PATCH + 1))
        else
            # No conventional commits found, check if there are any commits at all
            COMMIT_COUNT=$(echo "$COMMITS" | grep -v '^$' | wc -l | tr -d ' ')
            if [ "$COMMIT_COUNT" -gt 0 ]; then
                # Has commits but no conventional format, increment patch by default
                echo "  → No conventional commits found, incrementing PATCH by default"
                NEW_MAJOR=$LAST_MAJOR
                NEW_MINOR=$LAST_MINOR
                NEW_PATCH=$((LAST_PATCH + 1))
            else
                # No commits, keep same version
                NEW_MAJOR=$LAST_MAJOR
                NEW_MINOR=$LAST_MINOR
                NEW_PATCH=$LAST_PATCH
            fi
        fi
    fi
fi

NEW_VERSION="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"

echo ""
echo "========================================="
echo "Version Calculation Result"
echo "========================================="
echo "Previous Version: ${LAST_TAG_VERSION:-$BASE_VERSION}"
echo "New Version: ${NEW_VERSION}"
echo "========================================="
echo ""

# Output the new version (this will be captured by the calling script)
echo "${NEW_VERSION}"

