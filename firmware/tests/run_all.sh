#!/usr/bin/env bash
# Build and run all host-buildable firmware unit tests.
# Used by CI and for local verification.
set -e
cd "$(dirname "$0")"
for src in test_state_machine.cpp test_storage.cpp test_feedback.cpp test_button.cpp test_sensor.cpp test_power.cpp; do
  bin="${src%.cpp}"
  echo "==> $src"
  g++ -std=c++17 -I.. "$src" -o "$bin"
  "./$bin"
done
