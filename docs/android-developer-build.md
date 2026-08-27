# BCWMS Android — Developer Build Guide

Complete instructions for building, signing, and distributing BCWMS Android APK on macOS and Linux.

**Target:** BCWMS v1.10+  
**Kotlin:** 2.0.21  
**Android Gradle Plugin:** 8.6.1  
**Min SDK:** 26 (Android 8.0)  
**Target SDK:** 35 (Android 15)  
**Java/JDK:** 17 (required for Gradle 8.x)

---

## Prerequisites

### 1. Install Android Studio (or CLI tools)

**macOS (recommended):**
```bash
# Install via Homebrew
brew install android-studio

# Or download directly
# https://developer.android.com/studio (3+ GB)
```

**Linux:**
```bash
sudo apt-get install android-studio  # Ubuntu/Debian
# or download .tar.gz from https://developer.android.com/studio
```

### 2. Install Java Development Kit (JDK 17)

**macOS:**
```bash
# Check if JDK 17 is installed
java -version

# If not, install via Homebrew
brew install openjdk@17

# Set JAVA_HOME
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
# or ~/.bashrc for bash
source ~/.zshrc
java -version  # Verify → openjdk 17.x
```

**Linux:**
```bash
sudo apt-get install openjdk-17-jdk

# Verify
java -version  # openjdk 17.x
echo $JAVA_HOME  # Should be set (usually /usr/lib/jvm/java-17-openjdk-amd64)
```

### 3. Android SDK Setup

**Environment variables:**
```bash
# In ~/.zshrc or ~/.bashrc, add:
export ANDROID_HOME=~/Library/Android/sdk  # macOS
# or
export ANDROID_HOME=~/Android/Sdk  # Linux

# Add to PATH
export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

# Reload
source ~/.zshrc
```

**Verify SDK installation:**
```bash
sdkmanager --list_installed
# Should show:
# Android SDK Platform 35
# Android Emulator
# Android SDK Build-Tools 35.0.0
# Platform Tools
```

If missing components, install them:
```bash
sdkmanager "platforms;android-35" "build-tools;35.0.0" "emulator"
```

---

## Build Process

### Step 1: Clone Repository

```bash
cd ~/Projects  # or your preferred location
git clone https://github.com/DynOpsBC/WMS.git
cd WMS
```

### Step 2: Verify Environment Variables

```bash
echo "JAVA_HOME: $JAVA_HOME"
echo "ANDROID_HOME: $ANDROID_HOME"
echo "Java version:" && java -version
echo "Gradle version:" && ./gradlew --version

# If gradlew not executable:
chmod +x gradlew
```

### Step 3: Build Debug APK

Debug build (unsigned, for development/testing):

```bash
cd android

# Clean previous builds
./gradlew clean

# Build debug APK
./gradlew :app:assembleDebug

# Output path:
# app/build/outputs/apk/debug/app-debug.apk (3-5 MB)

# Watch build logs
./gradlew :app:assembleDebug --info
```

**Success output:**
```
> Task :app:assembleDebug
Built the following APK(s):
  app/build/outputs/apk/debug/app-debug.apk
```

### Step 4: Build Release APK (Signed)

For Play Store or production distribution, sign with your keystore.

#### 4a. Create or Use Existing Keystore

**Generate new keystore (one-time):**
```bash
keytool -genkey -v -keystore ~/bcwms.keystore \
  -keyalg RSA -keysize 2048 -validity 36500 \
  -alias bcwms-release

# Prompts:
# - Keystore password: [secure_password]
# - Key password: [same or different]
# - Name, Organization, City, Country: [your details]

# Output: ~/bcwms.keystore (created)
```

**Store credentials securely:**
```bash
# Never commit keystore to git!
# Save keystore password + alias in secure location (1Password, LastPass, etc.)

# In local.properties (git-ignored):
cat > android/local.properties << EOF
sdk.dir=$ANDROID_HOME
RELEASE_KEY_STORE=~/bcwms.keystore
RELEASE_KEY_STORE_PASSWORD=YourKeystorePassword
RELEASE_KEY_ALIAS=bcwms-release
RELEASE_KEY_PASSWORD=YourKeyPassword
EOF
```

**In build.gradle.kts (app/), define signing config:**
```kotlin
signingConfigs {
    release {
        storeFile = file(System.getenv("RELEASE_KEY_STORE") ?: "")
        storePassword = System.getenv("RELEASE_KEY_STORE_PASSWORD")
        keyAlias = System.getenv("RELEASE_KEY_ALIAS")
        keyPassword = System.getenv("RELEASE_KEY_PASSWORD")
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.release
        minifyEnabled = true
        proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
    }
}
```

#### 4b. Build Release APK

```bash
export RELEASE_KEY_STORE=~/bcwms.keystore
export RELEASE_KEY_STORE_PASSWORD="your-password"
export RELEASE_KEY_ALIAS="bcwms-release"
export RELEASE_KEY_PASSWORD="your-key-password"

# Build
./gradlew :app:assembleRelease

# Output path:
# app/build/outputs/apk/release/app-release.apk (2-3 MB, signed)

# Verify signing
jarsigner -verify -verbose app/build/outputs/apk/release/app-release.apk
```

---

## Testing on Emulator

### Start Emulator

```bash
# List available AVDs
emulator -list-avds

# Expected: Medium_Phone_API_35 (or similar)

# Launch
emulator -avd Medium_Phone_API_35 -no-snapshot-load &

# Watch boot logs (in another terminal)
adb logcat -c && adb logcat
```

### Install & Test APK on Emulator

```bash
# Install debug APK
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch app
adb shell am start -n com.dynops.bcwms/.MainActivity

# Watch logs
adb logcat -c && adb logcat | grep -E "BCWMS|ScanBus|MainActivity"

# Run on device (adb commands work for physical phones too)
adb devices  # List connected devices/emulators
```

### Run Unit Tests

```bash
./gradlew :app:testDebugUnitTest
# Output: app/build/reports/tests/testDebugUnitTest/index.html
```

---

## Gradle Tasks Reference

### Common Commands

```bash
# List all tasks
./gradlew tasks

# Build variants
./gradlew :app:assembleDynopsDebug    # Debug (flavor: dynops)
./gradlew :app:assembleBadeDebug      # Debug (flavor: bade)
./gradlew :app:assembleDebug          # Default debug

# Lint & checks
./gradlew :app:lintDebug
./gradlew :app:lintRelease

# Unit tests
./gradlew :app:testDebugUnitTest
./gradlew :app:testReleaseUnitTest

# Clean
./gradlew clean

# Full build (test + lint + assemble)
./gradlew :app:buildDebug
./gradlew :app:buildRelease
```

### Troubleshooting Gradle

**SDK not found:**
```
Error: Android SDK location not found.
```
→ Set `ANDROID_HOME` environment variable (see Prerequisites step 3).

**Kotlin compiler error:**
```
Error: Kotlin compilation failed
```
→ Clear Kotlin caches:
```bash
./gradlew clean
rm -rf .gradle
./gradlew build
```

**Gradle daemon memory:**
```
OutOfMemoryError: Java heap space
```
→ Increase memory in `gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4096m
```

---

## Distribution Channels

### Option 1: Google Play Store (Recommended)

1. **Set up Google Play Console:** https://play.google.com/console
2. **Create app listing** → accept Google Play policies
3. **Build signed APK** (see Step 4 above)
4. **Upload to Google Play Console:**
   - Internal Testing track first
   - Then Beta (closed track)
   - Finally Production
5. **Automated in-app updates:** Android app uses `UpdateManager.checkForUpdate()`

### Option 2: Firebase App Distribution (Faster testing)

```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Build release APK
./gradlew :app:assembleRelease

# Upload to Firebase
firebase appdistribution:distribute app/build/outputs/apk/release/app-release.apk \
  --release-notes="v1.10.0 production release" \
  --testers="team@dynops.com"

# Testers get email invite → install link
```

### Option 3: GitHub Releases (Direct download)

```bash
# Create release on GitHub
gh release create v1.10.0 \
  app/build/outputs/apk/release/app-release.apk \
  --notes "BCWMS v1.10.0 stable release"

# Link in docs/android-install-guide.md
# [releases/android/bcwms-1.10.0-release.apk](https://github.com/DynOpsBC/WMS/releases/download/v1.10.0/app-release.apk)
```

### Option 4: Internal Enterprise (MDM/EMM)

For Zebra/Samsung COPE devices via Mobile Device Management:

```bash
# Sign APK (see Step 4)
# Upload to MDM console (e.g., MobileIron, Intune, Zebra MX)
# Push to device fleet automatically
```

---

## CI/CD Integration (GitHub Actions)

**`.github/workflows/android-build.yml`:**
```yaml
name: Android Build

on:
  push:
    branches: [main]
    paths: [android/**, '.github/workflows/android-build.yml']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: 17
          distribution: temurin

      - name: Setup Android SDK
        uses: android-actions/setup-android@v3

      - name: Build APK
        working-directory: android
        run: ./gradlew assembleRelease
        env:
          RELEASE_KEY_STORE_PASSWORD: ${{ secrets.RELEASE_KEY_STORE_PASSWORD }}
          RELEASE_KEY_PASSWORD: ${{ secrets.RELEASE_KEY_PASSWORD }}

      - name: Upload to Firebase
        run: |
          npm install -g firebase-tools
          firebase appdistribution:distribute android/app/build/outputs/apk/release/app-release.apk \
            --token "${{ secrets.FIREBASE_TOKEN }}"
```

---

## Version Management

### Updating Version Numbers

**In `android/app/build.gradle.kts`:**
```kotlin
android {
    defaultConfig {
        versionCode = 1015  // Increment for each build
        versionName = "1.10.5"  // Semantic versioning
        minSdk = 26
        targetSdk = 35
    }
}
```

**In `android/app/src/main/AndroidManifest.xml`:**
- Android package name: `com.dynops.bcwms` (fixed)
- Version code in Gradle overrides any manifest value

### Release Checklist

- [ ] Update `versionCode` (increment by 1)
- [ ] Update `versionName` (semantic: major.minor.patch)
- [ ] Update `CHANGELOG.md` with features/fixes
- [ ] Build release APK + verify signing
- [ ] Test on physical device (or emulator)
- [ ] Create GitHub release / tag
- [ ] Upload to Play Store (internal testing first)
- [ ] Document in `releases/android/` directory

---

## Debugging

### View Logs in Real-Time

```bash
# Clear logcat buffer
adb logcat -c

# Watch logs
adb logcat -v threadtime | grep -E "BCWMS|BcApi|ScanBus|PackingModule"

# Save to file
adb logcat > ~/bcwms-logcat.txt &
# Then press Ctrl+C to stop
```

### Android Studio Debugger

```bash
# In Android Studio:
# 1. Run → Debug 'app' (instead of Run)
# 2. Set breakpoints in Kotlin source
# 3. Use Variables / Watches / Logcat panels
```

### adb Shell Commands

```bash
# Install APK (with debugging enabled)
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch app
adb shell am start -n com.dynops.bcwms/.MainActivity

# Kill app
adb shell am force-stop com.dynops.bcwms

# Clear app data (reset prefs/cache)
adb shell pm clear com.dynops.bcwms

# View installed packages
adb shell pm list packages | grep bcwms
```

---

## Performance Profiling

### Memory Profiler

```bash
# Via Android Studio:
# Profiler → Memory tab
# Capture heap dump → analyze in Android Studio
```

### Build Performance

```bash
./gradlew :app:assembleDebug --profile

# Profile report: android/build/reports/profile-<timestamp>/build/html/index.html
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **"Module not found: :app"** | Ensure `settings.gradle.kts` includes `:app`; run from `android/` directory |
| **Gradle sync fails** | Run `./gradlew sync` or File → Sync Now in Android Studio |
| **Unsigned APK error** | Use `assembleDebug` (unsigned) for testing; `assembleRelease` requires keystore |
| **App crashes on launch** | Check `adb logcat` for stack trace; likely missing BC token setup |
| **Scanner (barcode) not working** | Check scanner permission in `AndroidManifest.xml`; manual input fallback works |
| **Emulator too slow** | Use `emulator -avd ... -gpu on` (hardware acceleration); or test on physical device |

---

## References

- **Android Developer Docs:** https://developer.android.com/docs
- **Gradle Documentation:** https://docs.gradle.org
- **Kotlin Official:** https://kotlinlang.org/docs/
- **Android Gradle Plugin:** https://developer.android.com/build
- **BCWMS Source:** [android/](../android/) in this repo

---

## Support

- **Build issues:** File an issue on GitHub with `adb logcat` output
- **SDK/Gradle questions:** See Android Gradle Plugin docs or Stack Overflow
- **BCWMS-specific:** Contact support@dynops.com
