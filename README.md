# Building Android Apps with Gradle — No Android Studio Required

A complete, step-by-step guide to setting up, writing, building, and deploying Android applications using only the command line and a text editor.

---

## Table of contents

1. [How it all fits together](#1-how-it-all-fits-together)
2. [Prerequisites](#2-prerequisites)
3. [Install the Android SDK manually](#3-install-the-android-sdk-manually)
4. [Install Gradle](#4-install-gradle)
5. [Project structure](#5-project-structure)
6. [Configuration files explained](#6-configuration-files-explained)
7. [Write your first Activity](#7-write-your-first-activity)
8. [Build the APK](#8-build-the-apk)
9. [Run on a device or emulator](#9-run-on-a-device-or-emulator)
10. [Sign for release](#10-sign-for-release)
11. [Common Gradle tasks reference](#11-common-gradle-tasks-reference)
12. [ADB cheat sheet](#12-adb-cheat-sheet)
13. [Troubleshooting](#13-troubleshooting)
14. [Recommended tools](#14-recommended-tools)

---

## 1. How it all fits together

Android Studio is just a GUI wrapper. Under the hood it runs the exact same tools you will use here:

```
Your code (.kt / .java)
        │
        ▼
   Kotlin compiler  ──────────────────────────────────┐
        │                                             │
   Android resources (XML, drawables, strings)        │
        │                                             ▼
   AAPT2 (resource packager)              Compiled .class files
        │                                             │
        └──────────────────────────────► D8 / R8 (dex compiler)
                                                      │
                                                      ▼
                                               Unsigned APK
                                                      │
                                            apksigner / zipalign
                                                      │
                                                      ▼
                                               Signed APK
                                                      │
                                                   ADB install
                                                      │
                                                      ▼
                                              Device / Emulator
```

Gradle is the build system that orchestrates all of these steps. You describe what you want in `.gradle.kts` files and Gradle figures out the order.

---

## 2. Prerequisites

| Tool | Purpose |
|------|---------|
| JDK 17+ | Compiles Kotlin and runs Gradle |
| Android SDK | Platform tools, build tools, SDK platforms |
| Gradle 8+ | Build system (or use the Gradle wrapper bundled per project) |
| ADB | Install APKs and communicate with devices |
| A text editor | VS Code, Neovim, Sublime Text — anything works |

### Install JDK (if not already installed)

**macOS (Homebrew)**
```bash
brew install --cask temurin@17
```

**Ubuntu / Debian**
```bash
sudo apt update && sudo apt install -y openjdk-17-jdk
```

**Windows (winget)**
```bash
winget install EclipseAdoptium.Temurin.17.JDK
```

Verify the installation:
```bash
java -version
# Expected: openjdk version "17.x.x" ...

javac -version
# Expected: javac 17.x.x
```

---

## 3. Install the Android SDK manually

You do not need Android Studio to get the SDK. Google provides the **command-line tools** package separately.

### Step 1 — Download the command-line tools

Go to https://developer.android.com/studio#command-line-tools-only and download the zip for your OS, or use `curl`:

```bash
# Linux / macOS (replace the URL with the latest version)
mkdir -p ~/android-sdk/cmdline-tools
cd ~/android-sdk/cmdline-tools
curl -O https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest          # sdkmanager requires this exact folder name
```

> **Windows**: Download the zip, extract it to `C:\android-sdk\cmdline-tools\latest\`.

### Step 2 — Set environment variables

Add these to your shell profile (`~/.bashrc`, `~/.zshrc`, or Windows System Environment Variables):

```bash
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$ANDROID_HOME/build-tools/34.0.0"
```

Reload your shell:
```bash
source ~/.bashrc   # or source ~/.zshrc
```

### Step 3 — Accept licenses

```bash
sdkmanager --licenses
# Press y and Enter for each prompt
```

### Step 4 — Install the required SDK components

```bash
# Build tools, platform, and platform tools
sdkmanager "build-tools;34.0.0" "platforms;android-34" "platform-tools"

# Optional: system image for running an emulator
sdkmanager "system-images;android-34;google_apis;x86_64"
```

Verify everything installed:
```bash
sdkmanager --list_installed
```

---

## 4. Install Gradle

> **Tip:** In practice, every Android project ships with a **Gradle wrapper** (`gradlew` / `gradlew.bat`). Once you have a project, use `./gradlew` instead of a globally installed `gradle`. The wrapper downloads the exact Gradle version the project requires automatically.

### Install Gradle globally (for bootstrapping new projects)

**macOS (Homebrew)**
```bash
brew install gradle
```

**Ubuntu / Debian**
```bash
sdk install gradle 8.7   # via SDKMAN — recommended
# or
sudo apt install gradle  # may be outdated; prefer SDKMAN
```

**Windows (Scoop)**
```bash
scoop install gradle
```

Verify:
```bash
gradle --version
# Expected: Gradle 8.x
```

### Install SDKMAN (optional but useful)

SDKMAN lets you switch between JDK and Gradle versions easily:

```bash
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 17.0.11-tem
sdk install gradle 8.7
```

---

## 5. Project structure

A minimal Android project looks like this:

```
MyApp/
├── build.gradle.kts          # Root build file
├── settings.gradle.kts       # Project name + module list
├── gradle.properties         # Global Gradle flags
├── local.properties          # SDK path (not committed to git)
├── gradlew                   # Gradle wrapper script (Unix)
├── gradlew.bat               # Gradle wrapper script (Windows)
├── gradle/
│   └── wrapper/
│       └── gradle-wrapper.properties   # Wrapper version config
└── app/
    ├── build.gradle.kts      # App module build config
    └── src/
        └── main/
            ├── AndroidManifest.xml
            ├── kotlin/
            │   └── com/example/myapp/
            │       └── MainActivity.kt
            └── res/
                ├── layout/
                │   └── activity_main.xml
                └── values/
                    └── themes.xml
```

### Create the structure manually

```bash
PROJECT="MyApp"
PACKAGE="com/example/myapp"

mkdir -p $PROJECT/app/src/main/kotlin/$PACKAGE
mkdir -p $PROJECT/app/src/main/res/layout
mkdir -p $PROJECT/app/src/main/res/values
mkdir -p $PROJECT/gradle/wrapper
cd $PROJECT
```

---

## 6. Configuration files explained

### `settings.gradle.kts`

Defines the project name and which modules to include. Every project needs this.

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "MyApp"
include(":app")
```

### Root `build.gradle.kts`

Declares the plugins used across all modules. The `apply false` means "make this plugin available but don't apply it here — each module applies it themselves."

```kotlin
plugins {
    id("com.android.application") version "8.5.0" apply false
    kotlin("android")             version "2.0.21" apply false
}
```

### `app/build.gradle.kts`

The most important file — configures your app module.

```kotlin
plugins {
    id("com.android.application")
    kotlin("android")
}

android {
    namespace  = "com.example.myapp"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.myapp"
        minSdk        = 21       // Android 5.0+
        targetSdk     = 34
        versionCode   = 1
        versionName   = "1.0"
    }

    buildTypes {
        debug {
            isDebuggable    = true
            applicationIdSuffix = ".debug"   // optional: keeps debug + release installed side-by-side
        }
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.core:core-ktx:1.12.0")
}
```

### `gradle.properties`

```properties
# Give Gradle more heap memory for large projects
org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=512m

# Required for AndroidX
android.useAndroidX=true

# Migrate third-party libraries to AndroidX automatically
android.enableJetifier=true

# Speed up builds with parallel execution
org.gradle.parallel=true

# Cache build outputs between runs
org.gradle.caching=true
```

### `local.properties`

Points Gradle at your SDK installation. **Do not commit this file** — add it to `.gitignore`.

```properties
sdk.dir=/Users/yourname/android-sdk
```

Generate it automatically from your environment variable:
```bash
echo "sdk.dir=$ANDROID_HOME" > local.properties
```

### `gradle/wrapper/gradle-wrapper.properties`

Pins the Gradle version for everyone who works on the project.

```properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
```

Generate the wrapper files using your globally installed Gradle:
```bash
gradle wrapper --gradle-version 8.7
```

This creates `gradlew`, `gradlew.bat`, and the `gradle/wrapper/` directory. From this point on, use `./gradlew` for everything.

---

## 7. Write your first Activity

### `app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        android:label="My App"
        android:theme="@style/Theme.App">

        <activity
            android:name=".MainActivity"
            android:exported="true">

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

        </activity>

    </application>

</manifest>
```

### `app/src/main/kotlin/com/example/myapp/MainActivity.kt`

```kotlin
package com.example.myapp

import android.os.Bundle
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val textView = findViewById<TextView>(R.id.textHello)
        textView.text = "Hello from the command line!"
    }
}
```

### `app/src/main/res/layout/activity_main.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <TextView
        android:id="@+id/textHello"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="center"
        android:textSize="24sp"
        android:text="Hello!"/>

</FrameLayout>
```

### `app/src/main/res/values/themes.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.App" parent="Theme.AppCompat.Light.NoActionBar"/>
</resources>
```

---

## 8. Build the APK

All build commands use the Gradle wrapper (`./gradlew`). Never use a globally installed `gradle` inside a project — it may be a different version than what the wrapper pins.

### Debug build

```bash
./gradlew assembleDebug
```

Output: `app/build/outputs/apk/debug/app-debug.apk`

### Release build (unsigned)

```bash
./gradlew assembleRelease
```

Output: `app/build/outputs/apk/release/app-release-unsigned.apk`

### Build all variants at once

```bash
./gradlew assemble
```

### Clean + rebuild (fixes most "it worked yesterday" problems)

```bash
./gradlew clean assembleDebug
```

### Check build output size

```bash
ls -lh app/build/outputs/apk/debug/
```

### Speed up incremental builds

Gradle caches compiled outputs between runs. If you only changed one Kotlin file, subsequent builds take seconds. Enable the build cache explicitly if it isn't already in `gradle.properties`:

```properties
org.gradle.caching=true
org.gradle.parallel=true
```

---

## 9. Run on a device or emulator

### Connect a physical device

1. On the device: **Settings → About phone → tap "Build number" 7 times** to enable Developer Options.
2. Go to **Settings → Developer options → enable USB debugging**.
3. Connect via USB and accept the authorization prompt on the device.

### Verify ADB sees the device

```bash
adb devices
# Expected output:
# List of devices attached
# R5CW30XXXXX   device
```

### Install and launch

```bash
# Install the APK
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch MainActivity directly
adb shell am start -n "com.example.myapp/.MainActivity"
```

### One-liner: build + install + launch

```bash
./gradlew assembleDebug && \
  adb install -r app/build/outputs/apk/debug/app-debug.apk && \
  adb shell am start -n "com.example.myapp/.MainActivity"
```

Or use the built-in Gradle task (requires a connected device):

```bash
./gradlew installDebug
```

### Create and run an emulator

```bash
# List available system images
sdkmanager --list | grep "system-images"

# Install a system image
sdkmanager "system-images;android-34;google_apis;x86_64"

# Create an AVD (Android Virtual Device)
avdmanager create avd \
    --name "Pixel7_API34" \
    --package "system-images;android-34;google_apis;x86_64" \
    --device "pixel_7"

# Start the emulator (headless, faster)
emulator -avd Pixel7_API34 -no-window -no-audio &

# Wait for it to boot
adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'
echo "Emulator ready"

# Now install as normal
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

### Stream device logs

```bash
# All logs
adb logcat

# Filter to your app only
adb logcat --pid=$(adb shell pidof -s com.example.myapp)

# Filter by tag and level (W = warnings and above)
adb logcat -s MainActivity:W
```

---

## 10. Sign for release

The Play Store requires a signed APK or AAB (Android App Bundle). Debug builds are auto-signed with a debug keystore — you only need this for release.

### Step 1 — Generate a keystore

```bash
keytool -genkey -v \
    -keystore my-release-key.jks \
    -alias my-key-alias \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000
```

You will be prompted for a keystore password, key password, and your details (name, org, country). Keep the `.jks` file and both passwords safe — **you cannot re-sign a published app with a different key**.

### Step 2 — Add signing config to `app/build.gradle.kts`

Never hard-code passwords in your build file. Read them from environment variables or a local `keystore.properties` file that is excluded from version control.

**Using a `keystore.properties` file (recommended for local development):**

Create `keystore.properties` (add to `.gitignore`):
```properties
storeFile=/absolute/path/to/my-release-key.jks
storePassword=your_store_password
keyAlias=my-key-alias
keyPassword=your_key_password
```

Then reference it in `app/build.gradle.kts`:
```kotlin
import java.util.Properties

val keystoreProps = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) load(f.inputStream())
}

android {
    signingConfigs {
        create("release") {
            storeFile     = file(keystoreProps["storeFile"] as String)
            storePassword = keystoreProps["storePassword"] as String
            keyAlias      = keystoreProps["keyAlias"] as String
            keyPassword   = keystoreProps["keyPassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig   = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

**Using environment variables (recommended for CI):**
```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile     = file(System.getenv("KEYSTORE_PATH") ?: "")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
            keyAlias      = System.getenv("KEY_ALIAS") ?: ""
            keyPassword   = System.getenv("KEY_PASSWORD") ?: ""
        }
    }
}
```

### Step 3 — Build the signed release APK

```bash
./gradlew assembleRelease
```

Output: `app/build/outputs/apk/release/app-release.apk`

### Step 4 — Build an AAB (for Play Store)

The Play Store prefers AABs — they're smaller and let Google optimize the download for each device.

```bash
./gradlew bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`

### Step 5 — Verify the signature

```bash
apksigner verify --verbose app/build/outputs/apk/release/app-release.apk
```

---

## 11. Common Gradle tasks reference

Run any task with `./gradlew <task>`. Add `--info` or `--debug` for verbose output.

| Task | What it does |
|------|-------------|
| `assembleDebug` | Build debug APK |
| `assembleRelease` | Build release APK |
| `assemble` | Build all variants |
| `bundleRelease` | Build release AAB for Play Store |
| `installDebug` | Build + install debug APK on connected device |
| `clean` | Delete all build outputs |
| `test` | Run unit tests |
| `connectedAndroidTest` | Run instrumentation tests on a connected device |
| `lint` | Run Android lint checks |
| `lintDebug` | Lint on the debug variant only |
| `dependencies` | Print the full dependency tree |
| `tasks` | List all available tasks |
| `tasks --all` | List every task including internal ones |
| `properties` | Print all project properties |
| `signingReport` | Show signing key info for each variant |

### Useful flags

```bash
# Run a specific task and skip everything it doesn't need
./gradlew assembleDebug --rerun-tasks

# See why a task ran or was skipped
./gradlew assembleDebug --info

# Parallel execution (faster on multi-core machines)
./gradlew assembleDebug --parallel

# Offline mode — use cached dependencies only (no network)
./gradlew assembleDebug --offline

# Profile build times
./gradlew assembleDebug --profile
# Opens an HTML report in build/reports/profile/
```

---

## 12. ADB cheat sheet

```bash
# ── Devices ──────────────────────────────────────
adb devices                          # List connected devices
adb -s <serial> <command>            # Target a specific device

# ── Install / uninstall ──────────────────────────
adb install app.apk                  # Install APK
adb install -r app.apk               # Reinstall (keeps data)
adb install -d app.apk               # Allow version downgrade
adb uninstall com.example.myapp      # Uninstall app

# ── Launch / stop ────────────────────────────────
adb shell am start -n "com.example.myapp/.MainActivity"
adb shell am force-stop com.example.myapp

# ── Logs ─────────────────────────────────────────
adb logcat                                         # All logs
adb logcat *:E                                     # Errors only
adb logcat -s MyTag                                # Filter by tag
adb logcat --pid=$(adb shell pidof -s com.example.myapp)  # Your app only
adb logcat -c                                      # Clear log buffer

# ── File system ──────────────────────────────────
adb push local-file.txt /sdcard/                  # Copy to device
adb pull /sdcard/file.txt ./                      # Copy from device
adb shell ls /sdcard/                             # List files

# ── Screen ───────────────────────────────────────
adb shell screencap /sdcard/screen.png && adb pull /sdcard/screen.png
adb shell screenrecord /sdcard/demo.mp4           # Record screen (Ctrl-C to stop)

# ── Network ──────────────────────────────────────
adb tcpip 5555                                    # Switch to TCP/IP mode
adb connect 192.168.1.100:5555                    # Connect wirelessly
adb disconnect                                    # Disconnect wireless

# ── App data ─────────────────────────────────────
adb shell pm clear com.example.myapp             # Clear app data
adb shell pm list packages                       # List installed packages
adb shell dumpsys package com.example.myapp      # App info dump

# ── Device info ──────────────────────────────────
adb shell getprop ro.build.version.release       # Android version
adb shell getprop ro.product.model               # Device model
adb shell df -h                                  # Storage info
```

---

## 13. Troubleshooting

### `ANDROID_HOME is not set` or `SDK location not found`

```bash
# Check your environment
echo $ANDROID_HOME

# If empty, set it and add to your shell profile
export ANDROID_HOME="$HOME/android-sdk"
echo 'export ANDROID_HOME="$HOME/android-sdk"' >> ~/.zshrc

# Or write local.properties manually
echo "sdk.dir=$HOME/android-sdk" > local.properties
```

---

### `Could not resolve com.android.tools.build:gradle:8.5.0`

Gradle can't reach Maven repositories. Check your internet connection, then try:

```bash
# Force dependency refresh
./gradlew assembleDebug --refresh-dependencies

# Check if you're behind a corporate proxy
./gradlew assembleDebug -Dhttp.proxyHost=proxy.company.com -Dhttp.proxyPort=8080
```

---

### `Minimum supported Gradle version is X. Current version is Y`

Your wrapper version is too old for the AGP version you've declared. Update `gradle-wrapper.properties`:

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-bin.zip
```

Then re-run:
```bash
./gradlew wrapper --gradle-version 8.7
```

---

### `error: cannot find symbol` — R class missing

The resource compiler failed silently. Look further up in the build output for the real error (usually a malformed XML file). Common causes:

- A layout XML has a typo or missing closing tag
- A string resource is duplicated
- An `android:id` references a non-existent resource

```bash
# Run lint to catch resource errors before building
./gradlew lintDebug
```

---

### `adb: device unauthorized`

The device is connected but hasn't approved your computer yet.

1. On the device, look for an "Allow USB debugging?" dialog and tap **Allow**.
2. If there's no dialog: **Settings → Developer options → Revoke USB debugging authorizations**, then reconnect.

```bash
adb kill-server && adb start-server
adb devices   # should now show "device" instead of "unauthorized"
```

---

### `INSTALL_FAILED_UPDATE_INCOMPATIBLE`

The APK on the device was signed with a different key than the one you're installing now.

```bash
# Uninstall the old version first
adb uninstall com.example.myapp
adb install app/build/outputs/apk/debug/app-debug.apk
```

---

### Build is slow

```bash
# 1. Add to gradle.properties
org.gradle.caching=true
org.gradle.parallel=true
org.gradle.daemon=true

# 2. Check how much heap Gradle has
./gradlew --status

# 3. Profile which tasks are taking the longest
./gradlew assembleDebug --profile
# Then open the HTML report linked in the terminal output
```

---

### `Kotlin: error: unresolved reference`

Usually means a dependency is missing from `app/build.gradle.kts`, or you're referencing code in a different module without declaring a dependency on it.

```bash
# Print the full dependency tree to spot missing or conflicting libraries
./gradlew dependencies --configuration debugRuntimeClasspath
```

---

### Out of memory during build (`Java heap space`)

```properties
# In gradle.properties — increase heap
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g
```

---

## 14. Recommended tools

These are optional but significantly improve the command-line experience.

| Tool | What it does | Install |
|------|-------------|---------|
| **VS Code** + Kotlin extension | Syntax highlighting, basic completions | [code.visualstudio.com](https://code.visualstudio.com) |
| **IntelliJ IDEA Community** | Full Kotlin IDE, free, lighter than Android Studio | [jetbrains.com/idea](https://www.jetbrains.com/idea/) |
| **SDKMAN** | Manage multiple JDK and Gradle versions | `curl -s "https://get.sdkman.io" \| bash` |
| **scrcpy** | Mirror and control Android device screen from your desktop | `brew install scrcpy` / `apt install scrcpy` |
| **pidcat** | Colourized, readable `logcat` output filtered by package | `brew install pidcat` |
| **Fastlane** | Automate builds, signing, and Play Store uploads | `gem install fastlane` |
| **jadx** | Decompile APKs back to readable Java/Kotlin (useful for debugging) | [github.com/skylot/jadx](https://github.com/skylot/jadx) |
| **bundletool** | Google's official tool to inspect and install AABs | [github.com/google/bundletool](https://github.com/google/bundletool) |

---

## `.gitignore` for Android projects

```gitignore
# Build outputs
/build/
app/build/

# Gradle wrapper cache
.gradle/

# Local configuration — never commit these
local.properties
keystore.properties
*.jks
*.keystore

# IDE files
.idea/
*.iml
.DS_Store

# Android Studio navigation editor
app/src/main/res/navigation/
```

---

*Last updated for: AGP 8.5.0 · Gradle 8.7 · Kotlin 2.0.21 · compileSdk 34*
