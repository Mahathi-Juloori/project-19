#!/bin/bash

# GFGPay Setup Script for macOS/Linux

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   💳 GFGPay - Setup Script (macOS/Linux)                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+"
    exit 1
fi
echo "✅ Node.js $(node -v) is installed"

# Check npm
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed"
    exit 1
fi
echo "✅ npm $(npm -v) is installed"

echo ""
echo "Installing dependencies..."
npm install

echo ""
echo "Setting up environment..."
if [ ! -f .env ]; then
    cp env.example .env
    echo "✅ Created .env file"
else
    echo "✅ .env file already exists"
fi

# Create logs directory
mkdir -p logs

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   ✅ Setup Complete!                                      ║"
echo "║                                                           ║"
echo "║   Next steps:                                             ║"
echo "║   1. Update .env with your MongoDB URI                    ║"
echo "║   2. Run 'npm run seed' to create test data               ║"
echo "║   3. Run 'npm run dev' to start the server                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
