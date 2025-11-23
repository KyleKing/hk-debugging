#!/bin/bash

# Test runner for all demos
echo "🚀 Running Browser Extension Implementation Demos"
echo "=================================================="

# Check if Playwright is installed
if ! command -v npx &> /dev/null; then
    echo "❌ npx not found. Install Node.js first."
    exit 1
fi

# Create package.json if doesn't exist
if [ ! -f "package.json" ]; then
    echo "📦 Creating package.json..."
    cat > package.json <<EOF
{
  "name": "browser-extension-demos",
  "version": "1.0.0",
  "description": "Demos for DeploySentinel modifications",
  "scripts": {
    "test": "playwright test",
    "test:headed": "playwright test --headed"
  },
  "devDependencies": {
    "@playwright/test": "^1.40.0"
  }
}
EOF
fi

# Install dependencies
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Run tests
echo ""
echo "🧪 Running automated tests..."
npx playwright test --reporter=list

echo ""
echo "=================================================="
echo "✅ All demos complete!"
echo ""
echo "Manual testing:"
echo "  1. Open demos/test-*.html in browser"
echo "  2. Follow instructions in each page"
echo "  3. For HAR demo, DevTools must be open"
