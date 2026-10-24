# Selena Roller for iPhone

This folder turns the web game into a native iPhone app. There is no Mac involved: GitHub builds the app on one of
its own Mac machines (GitHub Actions) and can upload it straight to App Store Connect and TestFlight.

## What the app is

- One screen: a full-screen web view that runs the same game as https://ozduy.github.io/selena-roller/.
- The game files (`index.html`, `three.min.js`, `fonts/`, the icons and the manifest) stay at the top of the
  repository. `scripts/bundle-web.sh` copies them into the app as `web/` every time the app is built, so they are
  never kept twice in git.
- The app serves those files to the web view itself, at `selenaroller://localhost/`. Nothing is loaded from the
  internet, so the game works in airplane mode and the app collects no data.
- iPhone only, portrait only, iOS 17.0 or later (iPhone XS / XR and newer). Status bar hidden, home indicator
  hides itself, no scrolling, bouncing or zooming. Sound follows the silent switch and mixes with music.
- Saved progress lives in the web view's storage for `selenaroller://localhost`. Never change that scheme or host
  in `GameViewController.swift` after release, or players lose their progress.

## Files

| File | What it does |
| --- | --- |
| `project.yml` | Describes the Xcode project. The build turns it into `SelenaRoller.xcodeproj` with XcodeGen. |
| `SelenaRoller/AppDelegate.swift` | App start-up, sound settings and the window. |
| `SelenaRoller/GameViewController.swift` | The full-screen web view and its settings. |
| `SelenaRoller/BundleSchemeHandler.swift` | Serves the bundled game files to the web view. |
| `SelenaRoller/Info.plist` | App name, version, launch screen colour, portrait only, no encryption. |
| `SelenaRoller/PrivacyInfo.xcprivacy` | Privacy manifest: no tracking, no data collected. |
| `SelenaRoller/Assets.xcassets` | The 1024 x 1024 app icon and the launch screen colour. |
| `scripts/bundle-web.sh` | Copies the game into the app during the build. |
| `ExportOptions.plist` | Tells Xcode to sign for the App Store and upload. |
| `../.github/workflows/ios.yml` | The build itself. |

## How the build works

**On every push** to `ios-app` or `main` that changes the app or the game files, GitHub:

1. starts a Mac with Xcode 26.6 (iOS 26.5 SDK, which App Store Connect accepts),
2. creates the Xcode project from `project.yml`,
3. builds the app for the iPhone simulator, with no signing and no Apple account,
4. opens it in an iPhone simulator and saves a screenshot. Download it from the run page under
   **Artifacts > simulator-screenshot** to see the game running. In this test build, any script error is
   printed at the bottom of the screen.

**To send a build to App Store Connect**: on GitHub open **Actions > iOS app > Run workflow**, choose the branch,
tick **upload**, and press **Run workflow**. After the simulator check passes, GitHub:

1. archives the app (version 1.0, build number = the workflow's run number),
2. signs it with Apple's cloud-managed distribution certificate using the App Store Connect API key,
3. uploads it to App Store Connect. Apple emails when the build has been processed (usually 5 to 30 minutes);
   it then appears under TestFlight, ready for testing and for App Store submission.

GitHub shows the **Run workflow** button only once this workflow file is on the default branch (`main`). Until
then, a run with **upload** can be started through the GitHub API or the `gh` command line against the `ios-app`
branch (`gh workflow run ios.yml --ref ios-app -f upload=true`), as long as the workflow has run there once.

Each run has its own build number. If an upload run fails part way, start a new run rather than re-running the
old one, because Apple refuses a build number it has already received.

## The four GitHub secrets

Add them under **Settings > Secrets and variables > Actions > New repository secret**. The workflow checks that
all four exist before it starts and never prints them.

| Secret | What it is | Where to find it |
| --- | --- | --- |
| `ASC_KEY_ID` | The ID of an App Store Connect API key (10 characters). | App Store Connect > Users and Access > Integrations > App Store Connect API > Team Keys. |
| `ASC_ISSUER_ID` | The issuer ID for your API keys (a long ID with dashes). | Shown above the list of team keys on the same page. |
| `ASC_KEY_P8_BASE64` | The key file `AuthKey_<KEY ID>.p8`, base64-encoded. | Downloaded when the key is created (Apple lets you download it only once). |
| `APPLE_TEAM_ID` | Your Apple Developer team ID (10 characters). | developer.apple.com > Account > Membership details. |

The API key must be a **Team key with Admin access**. Keys with lower roles cannot use Apple's cloud signing and
the upload stops with a "Cloud signing permission error".

To turn the key file into the base64 text on Windows, run this in PowerShell (change the path to your file); it
copies the text to the clipboard, ready to paste as the secret value:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\Downloads\AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
```

Never put the `.p8` file, certificates or profiles in the repository; `.gitignore` blocks them.

## Before the first upload

- The app record must exist in App Store Connect (**Apps > + > New App**, iOS, bundle ID
  `com.ozduy.selenaroller`). Apple does not let a build create it.
- The account holder must have accepted the latest agreements in App Store Connect.

## Later changes

- **New version**: raise `MARKETING_VERSION` in `project.yml` (for example to `1.1`) after each App Store
  release.
- **Game changes** need nothing here: edit the files at the top of the repository and the next build picks them
  up. If `index.html` starts using a new file or folder, add it to `scripts/bundle-web.sh` (the build stops with
  a clear message if a linked file is missing).
- **Xcode 27**: Apple has announced that from April 2027 apps must be built with the iOS 27 SDK. The app already
  uses the scene life cycle and a launch screen, which that SDK requires. To move, change `runs-on` and
  `DEVELOPER_DIR` in the workflow, then check that the game copes with the window being resized.
