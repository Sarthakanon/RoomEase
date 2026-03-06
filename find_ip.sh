#!/bin/bash

echo "========================================="
echo "  Finding Your Backend Server IP"
echo "========================================="
echo ""

# Try different methods to find IP
if command -v hostname &> /dev/null; then
    echo "Method 1 - hostname -I:"
    hostname -I | awk '{print "  → " $1}'
    echo ""
fi

if command -v ip &> /dev/null; then
    echo "Method 2 - ip addr:"
    ip addr show | grep "inet " | grep -v 127.0.0.1 | awk '{print "  → " $2}' | cut -d'/' -f1
    echo ""
fi

if command -v ifconfig &> /dev/null; then
    echo "Method 3 - ifconfig:"
    ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print "  → " $2}'
    echo ""
fi

echo "========================================="
echo "Use one of the IPs above in the app's"
echo "Settings → Backend Server"
echo "========================================="
