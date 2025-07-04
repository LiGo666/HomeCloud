#!/bin/bash

# Test script for CrowdSec Traefik bouncer
# This script safely tests the CrowdSec bouncer without affecting SSH connections

# Define a test IP that won't affect your SSH connection
# Using a reserved documentation IP (RFC 5737)
TEST_IP="192.0.2.123"

echo "=== CrowdSec Traefik Bouncer Test ===" 
echo ""

# Function to make a normal request to whoami service
make_normal_request() {
  echo "Making normal request to whoami service..."
  curl -s -k -H "Host: whoami.localhost" https://localhost | head -n 5
  echo ""
}

# Function to check current CrowdSec decisions
check_decisions() {
  echo "Checking current CrowdSec decisions..."
  docker exec -it crowdsec cscli decisions list
  echo ""
}

# Function to add a test ban for a specific IP
add_test_ban() {
  echo "Adding test ban for IP ${TEST_IP}..."
  docker exec -it crowdsec cscli decisions add --ip "${TEST_IP}" --duration 2m --reason "Testing CrowdSec Traefik bouncer"
  echo ""
}

# Function to make a request simulating the banned IP
make_banned_request() {
  echo "Making request simulating banned IP ${TEST_IP}..."
  # Using X-Forwarded-For header to simulate the banned IP
  curl -s -k -v -H "Host: whoami.localhost" -H "X-Original-Forwarded-For: ${TEST_IP}" https://localhost 2>&1 | grep -E "< HTTP|< content-|^*|^>"
  echo ""
}

# Function to clean up test ban
cleanup() {
  echo "Cleaning up test ban..."
  docker exec -it crowdsec cscli decisions delete --ip "${TEST_IP}"
  echo ""
}

# Main test flow
echo "1. Testing normal access to whoami service"
make_normal_request

echo "2. Checking current CrowdSec decisions"
check_decisions

echo "3. Adding test ban for IP ${TEST_IP}"
add_test_ban

echo "4. Checking that ban was added"
check_decisions

echo "5. Testing access simulating banned IP"
make_banned_request

echo "6. Cleaning up test ban"
cleanup

echo "7. Verifying normal access is restored"
make_normal_request

echo "=== Test completed ==="
