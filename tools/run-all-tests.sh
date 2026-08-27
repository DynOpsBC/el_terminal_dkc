#!/usr/bin/env bash
# BCWMSApp — full client/backend test suite orchestrator.
# Çalıştırma: ./tools/run-all-tests.sh [--quick]
#   --quick: typecheck + build only, unit tests'i atla
#
# Çıktı: her subsystem için PASS/FAIL satırı, log /tmp/bcwms-tests/ altında.
# Exit kodu: ilk başarısız subsystem'in kodu, ya da hepsi başarılıysa 0.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="/tmp/bcwms-tests"
mkdir -p "$LOG_DIR"

QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

FAIL=0
declare -a RESULTS

bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m" "$*"; }
red()   { printf "\033[31m%s\033[0m" "$*"; }
yellow(){ printf "\033[33m%s\033[0m" "$*"; }

run() {
  local label="$1"; shift
  local logfile="$LOG_DIR/${label// /_}.log"
  bold "▶ $label"
  if (cd "$ROOT" && "$@") > "$logfile" 2>&1; then
    RESULTS+=("$(green '✅ PASS') $label  ($logfile)")
  else
    local rc=$?
    RESULTS+=("$(red   '❌ FAIL') $label  (rc=$rc, $logfile)")
    FAIL=$rc
    tail -25 "$logfile" | sed 's/^/    /'
  fi
}

# ---------------------------------------------------------------------------
# 1) Android (gradle)
# ---------------------------------------------------------------------------
if [[ -d "$ROOT/android" ]] && command -v ./android/gradlew >/dev/null 2>&1; then
  # iCloud sync zaman zaman " 2.dex/.class" duplicate'leri yaratır — clean.
  find "$ROOT/android/app/build" \( -name "* 2.dex" -o -name "* 2.class" -o -name "* 2.jar" \) -delete 2>/dev/null || true

  JAVA_HOME_OPT="${JAVA_HOME:-$HOME/.local/jdk/jdk-21.0.11+10/Contents/Home}"
  ANDROID_SDK_OPT="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  if [[ -d "$ANDROID_SDK_OPT" ]] && [[ -d "$JAVA_HOME_OPT" ]]; then
    if [[ "$QUICK" -eq 1 ]]; then
      run "android assembleDebug" env JAVA_HOME="$JAVA_HOME_OPT" ANDROID_HOME="$ANDROID_SDK_OPT" \
        bash -c "cd android && ./gradlew :app:assembleDebug"
    else
      run "android lint+unit+assemble" env JAVA_HOME="$JAVA_HOME_OPT" ANDROID_HOME="$ANDROID_SDK_OPT" \
        bash -c "cd android && ./gradlew :app:lintDebug :app:testDebugUnitTest :app:assembleDebug"
    fi
  else
    RESULTS+=("$(yellow '⏭ SKIP') android  (no Android SDK / JDK21 at $ANDROID_SDK_OPT)")
  fi
fi

# ---------------------------------------------------------------------------
# 2) Web (vite + vitest + playwright)
# ---------------------------------------------------------------------------
if [[ -f "$ROOT/web/package.json" ]]; then
  run "web typecheck"   bash -c "cd web && pnpm typecheck"
  run "web build"       bash -c "cd web && pnpm build"
  if [[ "$QUICK" -eq 0 ]]; then
    # Vitest unit tests (src/**/*.{test,spec}.{ts,tsx}). Şu an boş geçer.
    run "web vitest"    bash -c "cd web && pnpm exec vitest run --passWithNoTests"

    # Playwright e2e — tests/ klasöründeki spec'leri ve SelfTest panelini
    # gerçek tarayıcıda doğrular. Chromium browser kurulu değilse SKIP.
    if [[ -f "$ROOT/web/playwright.config.ts" ]] && [[ -d "$HOME/Library/Caches/ms-playwright" || -d "$HOME/.cache/ms-playwright" ]]; then
      run "web playwright" bash -c "cd web && pnpm exec playwright test"
    else
      RESULTS+=("$(yellow '⏭ SKIP') web playwright  (run 'cd web && pnpm test:e2e:install' once)")
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 3) Push relay (Azure Functions TS)
# ---------------------------------------------------------------------------
if [[ -f "$ROOT/push-relay/package.json" ]]; then
  run "push-relay build" bash -c "cd push-relay && pnpm build"
  [[ "$QUICK" -eq 0 ]] && run "push-relay test"  bash -c "cd push-relay && pnpm test"
fi

# ---------------------------------------------------------------------------
# 4) Licensing service (Azure Functions TS)
# ---------------------------------------------------------------------------
if [[ -f "$ROOT/licensing-service/package.json" ]]; then
  run "licensing build" bash -c "cd licensing-service && pnpm build"
  [[ "$QUICK" -eq 0 ]] && run "licensing test"  bash -c "cd licensing-service && pnpm test"
fi

# ---------------------------------------------------------------------------
# 5) Customer portal (Vite)
# ---------------------------------------------------------------------------
if [[ -f "$ROOT/customer-portal/package.json" ]]; then
  run "customer-portal typecheck" bash -c "cd customer-portal && pnpm typecheck"
  run "customer-portal build"     bash -c "cd customer-portal && pnpm build"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
bold "===== Sonuçlar ====="
for r in "${RESULTS[@]}"; do
  printf '%b\n' "$r"
done

exit "$FAIL"
