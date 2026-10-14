#!/bin/bash
# Scenarii de sincronizare pe Firebase Emulator Suite LOCAL + emulator Android
# dedicat și izolat. Vezi tooling/sync_emulator/README.md.
#
# Utilizare (din rădăcina repository-ului, Git Bash):
#   DEVICE=emulator-5596 OUT=<director rezultate> bash tooling/sync_emulator/run_sync_scenarios.sh
#
# Fiecare pas are timeout. La expirare sau la eșecul unei faze, scriptul
# salvează diagnosticul, oprește emulatoarele Firebase și se OPREȘTE (fazele
# depind una de alta, deci nu continuă).
set -u
export MSYS_NO_PATHCONV=1
DEVICE=${DEVICE:?setează DEVICE (emulator Android dedicat, NU 5592)}
OUT=${OUT:?setează OUT}
PROJECT=demo-proventaris-sync
PKG=ro.proterm.proventaris
TEST=integration_test/sync_emulator_test.dart
APK=build/app/outputs/flutter-apk/app-proterm-debug.apk
BUILD_TIMEOUT=${BUILD_TIMEOUT:-2400}   # s, build-ul APK de test
PHASE_TIMEOUT=${PHASE_TIMEOUT:-300}    # s, o fază pe dispozitiv
mkdir -p "$OUT"
[ "$DEVICE" = "emulator-5592" ] && { echo "REFUZ: 5592 nu se foloseste"; exit 2; }

# Orice comandă adb are timeout (implicit 30 s).
A() { timeout "${AT:-30}" adb -s "$DEVICE" "$@"; }

stop_emulators() {
  # DOAR procesele care ascultă pe porturile acestui test (+ hub/logging CLI).
  for port in 5310 5311 4400 4500 9150; do
    for pid in $(netstat -ano | awk -v p="127.0.0.1:$port" '{gsub(//,"")} $2==p && $4=="LISTENING" {print $5}' | sort -u); do
      # MSYS_NO_PATHCONV=1 (necesar pentru adb) => argumentele /F /PID ajung neconvertite.
      taskkill /F /PID "$pid" >/dev/null 2>&1
    done
  done
  sleep 2
  netstat -ano | grep -qE "127.0.0.1:(5310|5311|4400|4500|9150) .*LISTENING" \
    && echo "  ATENTIE: emulatoarele Firebase inca asculta" || echo "  emulatoarele Firebase oprite"
}

diagnose() {
  local tag=$1
  {
    echo "== DIAGNOSTIC $tag $(date +%H:%M:%S)"
    echo "app pid=[$(A shell pidof $PKG | tr -d '\r')]"
    A shell dumpsys activity activities | grep -m2 -E "topResumedActivity|mResumedActivity"
    echo "-- ultimele linii flutter"; A logcat -d -s flutter:I | tail -25
    echo "-- ANR/FATAL"; A logcat -d | grep -E "ANR in|FATAL EXCEPTION|am_crash" | tail -10
  } > "$OUT/diagnostic_$tag.txt" 2>&1
  sed 's/^/  /' "$OUT/diagnostic_$tag.txt" | head -45
}

# Fișiere modificate TEMPORAR doar pentru build-ul APK-ului de test:
# - google-services.json: project_id demo (aplicația Firebase nativă);
# - manifestul debug: usesCleartextTraffic (emulatorul Auth vorbește HTTP).
# Restaurate din git imediat după build și la orice ieșire.
GS=android/app/google-services.json
DM=android/app/src/debug/AndroidManifest.xml
restore_gs() {
  git checkout -- "$GS" "$DM" 2>/dev/null
  git diff --quiet -- "$GS" "$DM" && echo "  $GS si $DM restaurate (identice cu git)" || echo "  ATENTIE: $GS/$DM difera de git!"
}

fail() {
  echo "OPRIT: $*"
  A shell "sed -i '/fs-emulator.qa/d;/firestore.googleapis.com/d' /system/etc/hosts" >/dev/null 2>&1
  A reverse --remove-all >/dev/null 2>&1
  A shell am force-stop $PKG >/dev/null 2>&1
  stop_emulators
  exit 1
}

device_isolation() {
  local air routes addrs
  air=$(A shell settings get global airplane_mode_on | tr -d '\r')
  routes=$(A shell ip route | tr -d '\r')
  addrs=$(A shell ip -4 addr | grep -c "inet " | tr -d '\r')
  echo "  dispozitiv: airplane=$air routes=[$routes] interfete_ipv4=$addrs reverse=[$(A reverse --list | tr -d '\r' | tr '\n' ' ')]"
  [ "$air" = "1" ] && [ -z "$routes" ] && [ "$addrs" = "1" ] || fail "dispozitivul are ruta/interfata de retea"
}

online() {
  A reverse tcp:5310 tcp:5310 >/dev/null && A reverse tcp:5311 tcp:5311 >/dev/null || fail "adb reverse"
  A shell "grep -q firestore.googleapis.com /system/etc/hosts || echo '127.0.0.1       firestore.googleapis.com' >> /system/etc/hosts"
  echo "== ONLINE (doar tunel adb catre 127.0.0.1:5310/5311 al gazdei)"; device_isolation
}

offline() {
  A reverse --remove-all
  A shell "sed -i '/firestore.googleapis.com/d' /system/etc/hosts"
  echo "== OFFLINE"; device_isolation
}

run_phase() {
  local P=$1 KILL=${2:-}
  A shell "run-as $PKG sh -c 'mkdir -p files && echo $P > files/qa_sync_phase'" || fail "nu pot seta faza $P"
  A logcat -c
  A shell am start -n "$PKG/.MainActivity" >/dev/null || { diagnose "$P-start"; fail "lansare esuata ($P)"; }
  local start=$SECONDS killed=no result=""
  while [ $((SECONDS - start)) -lt "$PHASE_TIMEOUT" ]; do
    local log
    log=$(A logcat -d -s flutter:I)
    if [ -n "$KILL" ] && grep -q "SYNC_STARTED" <<<"$log"; then
      A shell am force-stop $PKG; killed=yes; result=killed; break
    fi
    if grep -q "All tests passed" <<<"$log"; then result=pass; break; fi
    if grep -q "Some tests failed" <<<"$log"; then result=fail; break; fi
    sleep 2
  done
  sleep 1
  A logcat -d -s flutter:I > "$OUT/logcat_$P.txt"
  echo "-- faza $P: ${result:-TIMEOUT} ($((SECONDS - start)) s)${KILL:+, oprire fortata in timpul sincronizarii: $killed}"
  grep -E "QA_SYNC|Expected|Actual|reason|Bad state" "$OUT/logcat_$P.txt" | sed 's/^.*flutter *: /  /' | head -30
  A shell am force-stop $PKG
  case "$result" in
    pass|killed) ;;
    fail) diagnose "$P"; fail "faza $P a esuat" ;;
    *) diagnose "$P-timeout"; fail "faza $P nu s-a terminat in ${PHASE_TIMEOUT}s" ;;
  esac
}

echo "== Pregatire $(date +%H:%M:%S)"
AT=60 A root >/dev/null 2>&1; sleep 2
A wait-for-device || fail "dispozitivul nu raspunde"
A reverse --remove-all
A shell "sed -i '/firestore.googleapis.com/d;/fs-emulator.qa/d' /system/etc/hosts"
# Nume dedicat pentru emulatorul Firebase (FlutterFire rescrie 127.0.0.1 în 10.0.2.2).
A shell "echo '127.0.0.1       fs-emulator.qa' >> /system/etc/hosts"
device_isolation

echo "== Build APK de test (o singura data, timeout ${BUILD_TIMEOUT}s) $(date +%H:%M:%S)"
# Doar pentru APK-ul de test: aplicația Firebase nativă (din google-services.json)
# primește project_id demo; fișierul e restaurat din git imediat după build,
# indiferent de rezultat. Build-urile release nu sunt afectate.
git diff --quiet -- "$GS" "$DM" || fail "$GS/$DM au modificari locale - refuz"
trap restore_gs EXIT
python -I -c "import json,sys;p=sys.argv[1];d=json.load(open(p));d['project_info']['project_id']=sys.argv[2];json.dump(d,open(p,'w'),indent=2)" "$GS" "$PROJECT"
sed -i 's#</manifest>#    <application android:usesCleartextTraffic="true" /></manifest>#' "$DM"
grep -q 'usesCleartextTraffic="true"' "$DM" || fail "nu am putut pregati manifestul debug"
echo "  project_id pentru build-ul de test: $(python -I -c "import json,sys;print(json.load(open(sys.argv[1]))['project_info']['project_id'])" "$GS")"
timeout "$BUILD_TIMEOUT" flutter build apk --debug --flavor proterm -t $TEST > "$OUT/build.log" 2>&1
BUILD_RC=$?
restore_gs
[ $BUILD_RC -eq 0 ] || { tail -15 "$OUT/build.log"; fail "build esuat sau expirat"; }
tail -1 "$OUT/build.log"
A uninstall $PKG >/dev/null 2>&1
AT=300 A install "$APK" | tail -1 || fail "instalare"

firebase emulators:start --project $PROJECT --config firebase.sync-test.json --only firestore,auth > "$OUT/firebase_emulators.log" 2>&1 &
for i in $(seq 1 90); do
  curl -s -m 2 http://127.0.0.1:5310/ >/dev/null && curl -s -m 2 http://127.0.0.1:5311/ >/dev/null && break
  [ "$i" = 90 ] && fail "emulatoarele Firebase nu au pornit in 180s"
  sleep 2
done
grep -E "All emulators ready|demo project" "$OUT/firebase_emulators.log" | sed 's/\x1b\[[0-9;]*m//g' | head -3
timeout 30 node tooling/sync_emulator/fs.mjs isolation || fail "emulatoarele locale nu raspund"

online
run_phase INIT
UID_=$(grep -o "UID=[A-Za-z0-9]*" "$OUT/logcat_INIT.txt" | head -1 | cut -d= -f2)
[ -n "$UID_" ] || fail "UID lipsa"
timeout 30 node tooling/sync_emulator/fs.mjs seed "$UID_" || fail "seed"
run_phase PULL

offline
timeout 30 node tooling/sync_emulator/fs.mjs edit-cloud || fail "edit-cloud"
run_phase OFFLINE_EDIT
run_phase RESTART_OFFLINE

online
run_phase SYNC
echo "-- verificare cloud dupa SYNC"; timeout 30 node tooling/sync_emulator/fs.mjs verify-sync | tee "$OUT/verify_after_sync.json"
timeout 30 node tooling/sync_emulator/fs.mjs delete-team t-cloud-2 || fail "delete-team"
run_phase PULL2
run_phase RETRY
run_phase KILL kill
run_phase AFTER_KILL
echo "-- verificare cloud finala"; timeout 30 node tooling/sync_emulator/fs.mjs verify-sync | tee "$OUT/verify_final.json"
echo "   jobs=$(timeout 30 node tooling/sync_emulator/fs.mjs count jobs) employees=$(timeout 30 node tooling/sync_emulator/fs.mjs count employees) teams=$(timeout 30 node tooling/sync_emulator/fs.mjs count teams)"

offline
run_phase CACHE

echo "== Proiect: singleProjectMode=$PROJECT; avertismente pentru alt projectId: $(grep -ciE 'multiple project|projectId.*(differ|mismatch)' "$OUT/firebase_emulators.log")"
A uninstall $PKG >/dev/null 2>&1
A shell "sed -i '/fs-emulator.qa/d;/firestore.googleapis.com/d' /system/etc/hosts"
stop_emulators
echo "== GATA $(date +%H:%M:%S)"
