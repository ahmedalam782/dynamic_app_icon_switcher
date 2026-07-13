#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/add_alternate_icon"
dart pub get
dart run bin/add_alternate_icon.dart "$@"
