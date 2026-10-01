#!/usr/bin/env bash
set -euo pipefail

set -a
source .env.prod
set +a

export ADMOB_IOS_APP_ID="${ADMOB_IOS_APP_ID:-ca-app-pub-3940256099942544~1458002511}"

flutter run --flavor prod -t lib/main_prod.dart
