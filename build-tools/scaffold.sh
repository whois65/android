#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# ANDROID PROJECT SCAFFOLD
# Templates: Webview | Home | Compose | MVVM | Bottom Nav
#
# Usage:
#   ./scaffold.sh                  — interactive prompts
#   ./scaffold.sh project.json     — config-driven (non-interactive)
#   CONFIG=./my.json ./scaffold.sh — config via env var
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# ───────────── helpers ─────────────
apply_template() {
    # Replace {{PACKAGE}} placeholder in a template file and write output
    local src="$1" dst="$2"
    sed "s|{{PACKAGE}}|$address|g" "$src" > "$dst"
}

require_template_dir() {
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        echo "ERROR: templates/ directory not found next to this script."
        echo "Expected: $TEMPLATES_DIR"
        exit 1
    fi
}

# Extract a top-level string field from a JSON file without requiring jq.
# Usage: json_field <file> <key>
# Returns the value or an empty string if the key is missing.
json_field() {
    local file="$1" key="$2"
    python3 -c "
import json, sys
try:
    d = json.load(open('$file'))
    print(d.get('$key', ''))
except Exception as e:
    sys.exit(0)
"
}

# Map a template name string to its numeric option (1-5).
# Accepts: webview | home | compose | mvvm | bottomnav (case-insensitive)
template_name_to_option() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        webview)   echo 1 ;;
        home)      echo 2 ;;
        compose)   echo 3 ;;
        mvvm)      echo 4 ;;
        bottomnav) echo 5 ;;
        *)
            echo "ERROR: Unknown template '$1'. Valid values: webview | home | compose | mvvm | bottomnav" >&2
            exit 1
            ;;
    esac
}

# ───────────── input — config file or interactive ─────────────

# Resolve config file: CLI arg > env var CONFIG > project.json next to script
CONFIG_FILE="${1:-${CONFIG:-$SCRIPT_DIR/project.json}}"

if [[ -f "$CONFIG_FILE" ]]; then
    echo "Reading config from: $CONFIG_FILE"

    appName=$(json_field "$CONFIG_FILE" appName)
    projectName=$(json_field "$CONFIG_FILE" projectName)
    address=$(json_field "$CONFIG_FILE" packageName)
    templateName=$(json_field "$CONFIG_FILE" template)

    # Validate required fields
    missing=()
    [[ -z "$appName" ]]     && missing+=("appName")
    [[ -z "$projectName" ]] && missing+=("projectName")
    [[ -z "$address" ]]     && missing+=("packageName")
    [[ -z "$templateName" ]] && missing+=("template")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: project.json is missing required field(s): ${missing[*]}"
        echo "Required fields: appName, projectName, packageName, template"
        exit 1
    fi

    templateOption=$(template_name_to_option "$templateName")

    echo "  appName     : $appName"
    echo "  projectName : $projectName"
    echo "  packageName : $address"
    echo "  template    : $templateName → option $templateOption"
    echo ""

else
    # ── interactive fallback ──
    if [[ -n "${1:-}" ]]; then
        # A path was given but the file doesn't exist — warn clearly
        echo "WARNING: Config file not found at '$1' — falling back to interactive mode."
        echo ""
    else
        echo "No project.json found — using interactive mode."
        echo "(Tip: run with a config file to skip prompts: ./scaffold.sh project.json)"
        echo ""
    fi

    read -r -p "Enter Application Name: " appName
    read -r -p "Enter Project Name: " projectName
    read -r -p "Enter Package Name (com.example.app): " address

    echo -e "\n== Choose Template ==\n"
    echo "  1. Webview       — full-screen WebView wrapping a URL"
    echo "  2. Home Page     — blank Activity, build from scratch"
    echo "  3. Compose       — Jetpack Compose + Material 3 scaffold"
    echo "  4. MVVM          — ViewModel + StateFlow + ViewBinding"
    echo "  5. Bottom Nav    — 3-tab bottom navigation with Fragments"
    echo ""
    read -r -p "Choose template (1-5): " templateOption
fi

# ───────────── validate inputs ─────────────
if [[ ! $address =~ ^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$ ]]; then
    echo "ERROR: Invalid package name '$address'"
    echo "Expected format: com.example.myapp"
    exit 1
fi

if [[ ! $templateOption =~ ^[1-5]$ ]]; then
    echo "ERROR: Invalid template option '$templateOption'. Must be 1–5."
    exit 1
fi

mkdir -p "$projectName"; cd "$projectName" || exit

echo "Initializing Gradle..."
gradle init --type basic <<EOF
$projectName
1
no
EOF
clear

# ───────────── package path ─────────────
sdkPath=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-""}}
packagePath=$(echo "$address" | tr '.' '/')

mkdir -p app/src/main/kotlin/$packagePath
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/menu

# ─────────────────────────────────────────────
# HEREDOC TEMPLATES  (simple — Webview, Home)
# ─────────────────────────────────────────────

webview_template() {
cat > app/src/main/kotlin/$packagePath/MainActivity.kt <<EOF
package $address

import android.os.Bundle
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        webView = findViewById(R.id.webView)

        WebView.setWebContentsDebuggingEnabled(true)

        webView.settings.apply {
            javaScriptEnabled  = true
            domStorageEnabled  = true
            setSupportZoom(true)
            builtInZoomControls  = true
            displayZoomControls  = false
            loadWithOverviewMode = true
            useWideViewPort      = true
        }

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?
            ): Boolean {
                view?.loadUrl(request?.url.toString())
                return true
            }
        }

        webView.loadUrl("https://youtube.com")
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (webView.canGoBack()) webView.goBack()
        else super.onBackPressed()
    }
}
EOF
}

home_template() {
cat > app/src/main/kotlin/$packagePath/MainActivity.kt <<EOF
package $address

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
    }
}
EOF
}

# ─────────────────────────────────────────────
# FILE-BASED TEMPLATES  (complex — Compose, MVVM, BottomNav)
# ─────────────────────────────────────────────

compose_template() {
    require_template_dir
    local uiThemeDir="app/src/main/kotlin/$packagePath/ui/theme"
    mkdir -p "$uiThemeDir"

    apply_template "$TEMPLATES_DIR/ComposeMainActivity.kt" \
        "app/src/main/kotlin/$packagePath/MainActivity.kt"

    apply_template "$TEMPLATES_DIR/AppTheme.kt" \
        "$uiThemeDir/AppTheme.kt"
}

mvvm_template() {
    require_template_dir

    apply_template "$TEMPLATES_DIR/MvvmMainActivity.kt" \
        "app/src/main/kotlin/$packagePath/MainActivity.kt"

    apply_template "$TEMPLATES_DIR/MainViewModel.kt" \
        "app/src/main/kotlin/$packagePath/MainViewModel.kt"

    # ViewBinding layout
    cat > app/src/main/res/layout/activity_main.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:gravity="center"
    android:orientation="vertical"
    android:padding="24dp">

    <TextView
        android:id="@+id/textStatus"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Ready"
        android:textSize="18sp"/>

    <Button
        android:id="@+id/buttonAction"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="24dp"
        android:text="Do Something"/>

</LinearLayout>
EOF
}

bottom_nav_template() {
    require_template_dir
    local fragDir="app/src/main/kotlin/$packagePath"

    # Fragments
    for frag in home dashboard profile; do
        local className
        className="$(tr '[:lower:]' '[:upper:]' <<< "${frag:0:1}")${frag:1}Fragment"
        mkdir -p "$fragDir/ui/$frag"

        if [[ -f "$TEMPLATES_DIR/HomeFragment.kt" && "$frag" == "home" ]]; then
            apply_template "$TEMPLATES_DIR/HomeFragment.kt" \
                "$fragDir/ui/$frag/${className}.kt"
        else
            # Generate dashboard / profile inline
            cat > "$fragDir/ui/$frag/${className}.kt" <<EOF
package $address.ui.$frag

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.fragment.app.Fragment
import $address.R

class ${className} : Fragment() {
    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val view = inflater.inflate(R.layout.fragment_$frag, container, false)
        view.findViewById<TextView>(R.id.textLabel).text = "${className/Fragment/}"
        return view
    }
}
EOF
        fi

        # Fragment layouts
        cat > "app/src/main/res/layout/fragment_$frag.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <TextView
        android:id="@+id/textLabel"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="center"
        android:textSize="20sp"/>

</FrameLayout>
EOF
    done

    # Bottom nav menu
    cat > app/src/main/res/menu/bottom_nav_menu.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<menu xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:id="@+id/nav_home"      android:title="Home"      android:icon="@android:drawable/ic_menu_compass"/>
    <item android:id="@+id/nav_dashboard" android:title="Dashboard" android:icon="@android:drawable/ic_menu_today"/>
    <item android:id="@+id/nav_profile"   android:title="Profile"   android:icon="@android:drawable/ic_menu_myplaces"/>
</menu>
EOF

    # Main layout with BottomNavigationView
    cat > app/src/main/res/layout/activity_main.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical">

    <FrameLayout
        android:id="@+id/fragmentContainer"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"/>

    <com.google.android.material.bottomnavigation.BottomNavigationView
        android:id="@+id/bottomNavigation"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        app:menu="@menu/bottom_nav_menu"/>

</LinearLayout>
EOF

    apply_template "$TEMPLATES_DIR/BottomNavMainActivity.kt" \
        "$fragDir/MainActivity.kt"
}

# ───────────── dispatch ─────────────
case $templateOption in
    1) echo "Applying Webview template..."   ; webview_template    ;;
    2) echo "Applying Home Page template..." ; home_template       ;;
    3) echo "Applying Compose template..."   ; compose_template    ;;
    4) echo "Applying MVVM template..."      ; mvvm_template       ;;
    5) echo "Applying Bottom Nav template..."; bottom_nav_template ;;
    *) echo "Invalid option!"; exit 1 ;;
esac

# ───────────── settings.gradle.kts ─────────────
cat > settings.gradle.kts <<EOF
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

rootProject.name = "$projectName"
include(":app")
EOF

# ───────────── local.properties ─────────────
cat > local.properties <<EOF
sdk.dir=$sdkPath
EOF

# ───────────── root build.gradle.kts ─────────────
cat > build.gradle.kts <<EOF
plugins {
    id("com.android.application") version "8.5.0" apply false
    kotlin("android")             version "2.0.21" apply false
}
EOF

# ───────────── app/build.gradle.kts (template-aware) ─────────────
compose_deps=""
compose_plugins=""
viewbinding_flag=""
material_dep=""

case $templateOption in
    3)  # Compose
        compose_plugins='    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21"'
        compose_deps='
    val composeBom = platform("androidx.compose:compose-bom:2024.05.00")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    debugImplementation("androidx.compose.ui:ui-tooling")'
        ;;
    4)  # MVVM — ViewBinding + lifecycle
        viewbinding_flag="
    buildFeatures { viewBinding = true }"
        compose_deps='
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.0")'
        ;;
    5)  # Bottom Nav — ViewBinding + Material
        viewbinding_flag="
    buildFeatures { viewBinding = true }"
        material_dep='    implementation("com.google.android.material:material:1.12.0")'
        ;;
esac

cat > app/build.gradle.kts <<EOF
plugins {
    id("com.android.application")
    kotlin("android")
$compose_plugins
}

android {
    namespace  = "$address"
    compileSdk = 34

    defaultConfig {
        applicationId = "$address"
        minSdk        = 21
        targetSdk     = 34
        versionCode   = 1
        versionName   = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }
$viewbinding_flag
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.core:core-ktx:1.12.0")
$compose_deps
$material_dep
}
EOF

# ───────────── gradle.properties ─────────────
compose_flag=""
[[ $templateOption == 3 ]] && compose_flag="android.defaults.buildfeatures.compose=true"

cat > gradle.properties <<EOF
org.gradle.jvmargs=-Xmx2g
android.useAndroidX=true
android.enableJetifier=true
$compose_flag
EOF

# ───────────── AndroidManifest.xml ─────────────
cat > app/src/main/AndroidManifest.xml <<EOF
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        android:label="$appName"
        android:usesCleartextTraffic="true"
        android:theme="@style/Theme.App">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:windowSoftInputMode="adjustResize">

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

        </activity>

    </application>

</manifest>
EOF

# ───────────── activity_main.xml (for Webview + Home + Compose only) ─────────────
# MVVM and BottomNav write their own layout above
case $templateOption in
    1)
        cat > app/src/main/res/layout/activity_main.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<WebView xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/webView"
    android:layout_width="match_parent"
    android:layout_height="match_parent"/>
EOF
        ;;
    2)
        cat > app/src/main/res/layout/activity_main.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"/>
EOF
        ;;
    3)  # Compose — no XML layout needed
        ;;
esac

# ───────────── themes.xml ─────────────
cat > app/src/main/res/values/themes.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.App" parent="Theme.AppCompat.Light.NoActionBar"/>
</resources>
EOF

# ───────────── BUILD ─────────────
echo ""
echo "Building APK..."
if ./gradlew assembleDebug; then
    echo "Installing APK..."
    adb install -r app/build/outputs/apk/debug/app-debug.apk
    adb shell am start -n "$address/.MainActivity"
else
    echo "Build failed!"
    exit 1
fi