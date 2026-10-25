# Selena Roller for iPhone

This folder turns the web game into a native iPhone app. There is no Mac involved: GitHub builds the app on one of
its own Mac machines (GitHub Actions) and can upload it straight to App Store Connect and TestFlight.

## What the app is

- One screen: a full-screen web view that runs the same game as https://ozduy.github.io/selena-roller/.
- The game files (`index.html`, `three.min.js`, `fonts/`, the icons, the manifest and `THIRD-PARTY-NOTICES.txt`)
  stay at the top of the repository. `scripts/bundle-web.sh` copies them into the app as `web/` every time the app
  is built, so they are never kept twice in git.
- The app serves those files to the web view itself, at `selenaroller://localhost/`. Nothing is loaded from the
  internet, so the game works in airplane mode and the app collects no data. The build stops if the game ever
  loads a script, stylesheet, font or picture from another site.
- The Help and Privacy links on the menu open the support page and the privacy policy in Safari. The game view
  itself never shows outside pages.
- iPhone only, portrait only, iOS 17.0 or later (iPhone XS / XR and newer). Status bar hidden, home indicator
  hides itself, no scrolling, bouncing or zooming. Always in the light appearance, so the launch screen and the
  first frame of the game are the same sky blue. Sound follows the silent switch and mixes with music.
- A level pauses when the player leaves the app, and also when Notification Centre, Control Centre, Siri or a call
  comes over it. If iOS stops the page three times within a minute (very low memory), the app waits for a tap or
  for the player to come back before loading the game again, instead of reloading over and over.
- Saved progress lives in the web view's storage for `selenaroller://localhost`. Never change that scheme or host
  in `GameViewController.swift` after release, or players lose their progress.

## Files

| File | What it does |
| --- | --- |
| `project.yml` | Describes the Xcode project. The build turns it into `SelenaRoller.xcodeproj` with XcodeGen. |
| `SelenaRoller/AppDelegate.swift` | App start-up, sound settings, the window, and pausing when the app stops being active. |
| `SelenaRoller/GameViewController.swift` | The full-screen web view and its settings. |
| `SelenaRoller/BundleSchemeHandler.swift` | Serves the bundled game files to the web view. |
| `SelenaRoller/Info.plist` | App name, version, launch screen colour, portrait only, light appearance, no encryption. |
| `SelenaRoller/PrivacyInfo.xcprivacy` | Privacy manifest: no tracking, no data collected. |
| `SelenaRoller/Assets.xcassets` | The 1024 x 1024 app icon and the launch screen colour. |
| `scripts/bundle-web.sh` | Copies the game into the app during the build, and stops the build if the game would load anything from the internet. |
| `ExportOptions.plist` | Tells Xcode to sign for the App Store and upload. |
| `../.github/workflows/ios.yml` | The build itself. |

## How the build works

**On every push** to `ios-app` or `main` that changes the app or the game files, GitHub:

1. starts a Mac with Xcode 26.6 (iOS 26.5 SDK, which App Store Connect accepts),
2. downloads XcodeGen 2.46.0 from its GitHub release, checks it against a fixed SHA-256, and creates the Xcode
   project from `project.yml`,
3. builds the app for the iPhone simulator, with no signing and no Apple account,
4. opens it in an iPhone simulator, saves a screenshot and checks that the app is still running 25 seconds later.
   If the app crashes, the build fails. Download the screenshot from the run page under
   **Artifacts > simulator-screenshot** to see the game running. In this test build, any script error is printed
   at the bottom of the screen.

**To send a build to App Store Connect**: on GitHub open **Actions > iOS app > Run workflow**, choose the branch,
tick **upload**, and press **Run workflow**. After the simulator check passes, GitHub:

1. archives the app (version 1.0; the build number is the workflow's run number and attempt, for example `12.1`),
2. signs it with Apple's cloud-managed distribution certificate using the App Store Connect API key,
3. uploads it to App Store Connect. Apple emails when the build has been processed (usually 5 to 30 minutes);
   it then appears under TestFlight, ready for testing and for App Store submission.

GitHub shows the **Run workflow** button only once this workflow file is on the default branch (`main`). Until
then, a run with **upload** can be started through the GitHub API or the `gh` command line against the `ios-app`
branch (`gh workflow run ios.yml --ref ios-app -f upload=true`), as long as the workflow has run there once.

Every run and every re-run gets its own build number, so an upload run that failed part way can simply be re-run.

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

Once the secret is saved on GitHub:

- clear the clipboard history if it is switched on (**Win+V > Clear all**), because the base64 text is the key
  itself,
- keep the `.p8` file in a password manager (Apple does not let you download it again) and delete it from
  Downloads,
- never save the base64 text in a file. Never put the `.p8` file, certificates or profiles in the repository;
  `.gitignore` blocks them, and also `*.p8.txt`, `*.b64`, `*.base64` and `.env*` files.

## Before the first upload

Do these in order. Steps 1 to 6 are on Apple's websites, and some of them only the account holder can do.

1. **Agreements**: App Store Connect > Business: accept the latest Apple Developer Program License Agreement.
   Apple does not allow new apps until it is accepted.
2. **API access and key**: App Store Connect > Users and Access > Integrations > App Store Connect API: request
   access once (account holder), then create a **Team key** with the **Admin** role and add the four secrets
   above.
3. **App ID**: developer.apple.com > Certificates, Identifiers & Profiles > Identifiers > **+** > App IDs > App:
   register the explicit bundle ID `com.ozduy.selenaroller` (description "Selena Roller", no capabilities). The
   New App form in step 4 only offers bundle IDs that are already registered.
4. **App record**: App Store Connect > Apps > **+** > New App: iOS, name "Selena Roller", primary language
   English (U.K.), bundle ID `com.ozduy.selenaroller`, SKU `SELENAROLLER-IOS`. A build cannot create it.
5. **Selling the app**: App Store Connect > Business: accept the Paid Apps Agreement, complete the tax forms (for
   an individual outside the US this is the W-8BEN form) and add a bank account in exactly the account's legal
   name. TestFlight works without this, but until the Paid Apps Agreement is active the app can only be free, and
   an approved paid version waits until it is. The App Store Small Business Program (15% commission instead of
   30%) is a separate application on developer.apple.com.
6. **EU trader status**: every account must declare a Digital Services Act trader status in App Store Connect, or
   the app is not offered in the EU. Selling a paid app normally counts as trading, and a trader's address, phone
   number and email are then shown on the App Store in the EU, so choose which ones to publish first (for example
   a business address or a verified P.O. box rather than a home address).
7. **First upload**: run the workflow with **upload** ticked (see above).
8. **Test on a real iPhone** through internal TestFlight: airplane mode; leave the app in the middle of a level and
   come back (the level should be paused); pull down Notification Centre in the middle of a level (paused); close
   the app fully and reopen it (progress kept); Silent mode (no sound); the Help and Privacy links open Safari.

Choices to make in App Store Connect > Pricing and Availability before submitting for review:

- **Price**: base country United Kingdom, expected GBP 0.99.
- **China mainland**: a game there needs a game approval number from China's NPPA, which this app does not have.
  Without one it cannot go on sale there and App Review may ask for the number, so the usual choice is to untick
  China mainland and keep every other country and region.
- **Mac and Apple Vision Pro**: iPhone apps are also offered on Apple silicon Macs and Apple Vision Pro unless
  those boxes are unticked. The game has not been tested on either.
- **Release**: "Manually release this version" lets you choose when the approved version goes on sale.

### If the first upload fails

Open the failed run and read the step **Show the end of the distribution log**.

| Message | Cause |
| --- | --- |
| Cloud signing permission error | The API key is not a Team key with the Admin role. |
| No profiles for `com.ozduy.selenaroller`, or the bundle identifier is not available | The App ID (step 3) is missing. |
| No suitable application records were found | The app record (step 4) is missing. |
| An entitlements or codesign error about the archive | The archive is made unsigned and signed at export. If Apple refuses that, signing has to move to the archive step of the workflow. |

## Later changes

- **New version**: raise `MARKETING_VERSION` in `project.yml` (for example to `1.1`) after each App Store
  release.
- **Game changes** need nothing here: edit the files at the top of the repository and the next build picks them
  up. If `index.html` starts using a new file or folder, add it to `scripts/bundle-web.sh` (the build stops with
  a clear message if a linked file is missing, or if the game would load anything from another site).
- **Xcode 27**: Apple has announced that from April 2027 apps must be built with the iOS 27 SDK. The app already
  uses the scene life cycle and a launch screen, which that SDK requires. To move, change `runs-on` and
  `DEVELOPER_DIR` in the workflow, then check that the game copes with the window being resized.
