# Android Project Scaffold

A Bash script that bootstraps a ready-to-build Android project in seconds. Pick a template, supply your app details, and get a fully wired Gradle project — built and installed on a connected device automatically.

---

## Requirements

| Tool | Minimum version | Notes |
|------|----------------|-------|
| Bash | 4.0+ | macOS ships Bash 3 — install via Homebrew: `brew install bash` |
| Gradle | 8.x | Must be on `PATH` |
| Android SDK | any recent | `ANDROID_HOME` or `ANDROID_SDK_ROOT` must be set |
| Python 3 | 3.6+ | Used to parse `project.json` — ships with macOS and most Linux distros |
| ADB | any | Required only for the final install + launch step |

---

## Repository layout

```txt
android-scaffold/
├── scaffold.sh          # Main script
├── project.json         # Config file (optional — see usage below)
├── PROJECT_JSON.md      # project.json field reference
├── README.md            # This file
└── templates/           # Kotlin source templates for complex layouts
    ├── ComposeMainActivity.kt
    ├── AppTheme.kt
    ├── MvvmMainActivity.kt
    ├── MainViewModel.kt
    ├── BottomNavMainActivity.kt
    └── HomeFragment.kt
```

> The `templates/` directory must sit next to `scaffold.sh`. The three complex templates (Compose, MVVM, Bottom Nav) read from it; the two simple ones (Webview, Home) are generated inline.

---

## Usage

### Interactive mode

Run the script with no arguments. It will prompt for each value and display a template menu.

```bash
chmod +x scaffold.sh
./scaffold.sh
```

### Config-driven mode (recommended)

Create a `project.json` file and pass it as the first argument — or place it next to the script for auto-detection.

```bash
# Auto-detect: looks for project.json next to scaffold.sh
./scaffold.sh

# Explicit path
./scaffold.sh path/to/project.json

# Via environment variable — useful in CI pipelines
CONFIG=./configs/staging.json ./scaffold.sh
```

If a config file path is given but the file does not exist, the script warns and falls back to interactive prompts.

---

## project.json

```json
{
  "appName":     "My App",
  "projectName": "MyAndroidProject",
  "packageName": "com.example.myapp",
  "template":    "compose"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `appName` | yes | Label shown on the device launcher |
| `projectName` | yes | Gradle root project name — no spaces |
| `packageName` | yes | Android application ID, e.g. `com.example.myapp` |
| `template` | yes | See template names below |

See `PROJECT_JSON.md` for the full field reference.

---

## Templates

| Name | Value in `project.json` | What gets generated |
|------|--------------------------|---------------------|
| Webview | `webview` | Full-screen `WebView` wrapping a URL, back-navigation handled |
| Home Page | `home` | Blank `AppCompatActivity` — start from scratch |
| Jetpack Compose | `compose` | `ComponentActivity` + `Scaffold` + `Material3` theme + `AppTheme.kt` |
| MVVM | `mvvm` | `ViewModel` + `StateFlow` + `MainUiState` + `ViewBinding` layout |
| Bottom Navigation | `bottomnav` | 3-tab `BottomNavigationView` with `HomeFragment`, `DashboardFragment`, `ProfileFragment` |

Each template also configures the correct Gradle dependencies automatically — you don't need to add anything by hand.

| Template | Extra dependencies added |
|----------|--------------------------|
| Compose | Compose BOM, `activity-compose`, Material 3, UI tooling |
| MVVM | `lifecycle-viewmodel-ktx`, `lifecycle-runtime-ktx`, ViewBinding enabled |
| Bottom Nav | `material:1.12.0`, ViewBinding enabled |

---

## What the script generates

For every template, the script creates a complete, buildable project:

```txt
<projectName>/
├── build.gradle.kts             # Root build file (AGP + Kotlin plugin)
├── settings.gradle.kts          # Module includes + repository config
├── gradle.properties            # JVM args, AndroidX, Jetifier
├── local.properties             # sdk.dir from $ANDROID_HOME
└── app/
    ├── build.gradle.kts         # App module — deps vary by template
    └── src/main/
        ├── AndroidManifest.xml
        ├── kotlin/<package>/    # MainActivity.kt (+ extras per template)
        └── res/
            ├── layout/          # XML layouts (where applicable)
            ├── menu/            # Bottom nav menu (bottomnav template only)
            └── values/
                └── themes.xml   # Theme.App — NoActionBar base
```

After scaffolding, the script runs `./gradlew assembleDebug` and, if the build succeeds, installs and launches the APK via ADB.

---

## CI example

Config-driven mode makes the script fully non-interactive, so it works cleanly in any CI environment.

```yaml
# .github/workflows/scaffold.yml
name: Scaffold and build

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Scaffold project
        run: |
          chmod +x scaffold.sh
          ./scaffold.sh project.json
        env:
          ANDROID_HOME: ${{ env.ANDROID_SDK_ROOT }}
```

---

## Adding a new template

1. Add the Kotlin source file(s) to `templates/`, using `{{PACKAGE}}` as the package name placeholder.
2. Add a new `apply_template` call inside a new `yourname_template()` function in `scaffold.sh`.
3. Add the function call to the `case $templateOption` dispatch block.
4. Add the template name → number mapping in `template_name_to_option()`.
5. Update the `app/build.gradle.kts` generation block if the template needs extra dependencies.

---

## License

MIT
