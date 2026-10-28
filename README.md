# TrollAppsTV — TrollStore Lite fix

An unofficial patched source package based on [TheResonanceTeam/TrollAppsTV](https://github.com/TheResonanceTeam/TrollAppsTV), commit `e289cbc02642b952f89fc6083b84ea6202381fa5`. Original license and upstream README are included. This is GPL-3.0 software, not an official Resonance Team release.

The original app downloads an IPA but only searches container directories for `TrollStore.app`. This build also recognizes TrollStore Lite in `/Applications` and `/var/jb/Applications`.

## Build an IPA using GitHub

You do not need Xcode on your own computer or an Apple developer account for this workflow. GitHub's macOS runner builds the app; it is packaged with the entitlements for installation through TrollStore Lite. Your account needs access to GitHub Actions macOS runners; usage may count against your plan.

1. Create a **separate** GitHub repository, for example `trollappstv-lite-fix`, with `main` as the default branch. Do not put these files into your IPA Shelf server repository.
2. Extract this archive and put its contents at the repository root, including the hidden `.github` directory. Commit and push to `main`.
3. Open **Actions → Build TrollAppsTV Lite fix**. The push starts a build, or use **Run workflow** on `main`.
4. Wait for a green result. In that run's **Artifacts** section, download **TrollAppsTV-Lite-Fix**. You must be signed in to GitHub to download an Actions artifact.
5. Extract the artifact. It contains `TrollAppsTV.ipa`, `TrollAppsTV.tipa` and `SHA256SUMS`. These are the built files; this source archive itself cannot be installed.

No publishing token or signing certificate secret is required. The workflow does not create releases or publish anything to GHCR. If the build fails, share the first failing step and its error; a successful workflow run is required before there is an IPA to install.

## Install on your Apple TV

First, close TrollAppsTV on the TV. From the computer where you downloaded the built IPA, copy it to your TV (replace the address if it changed):

```sh
scp TrollAppsTV.ipa mobile@192.168.1.74:/var/mobile/TrollAppsTV-LiteFix.ipa
```

In the Apple TV's existing SSH session, use the helper you already confirmed works:

```sh
sudo /Applications/TrollStoreLite.app/trollstorehelper install /var/mobile/TrollAppsTV-LiteFix.ipa
echo "Exit code: $?"
```

A successful installation normally returns `0`. Reopen TrollAppsTV and test one small app from your IPA Shelf tvOS source. Keep your current TrollAppsTV IPA as a rollback copy before updating.

This patch retains the original bundle identifier (`org.resonance.tvstore`) so it replaces the existing app. It does not intentionally reset source configuration. Avoid installing the upstream TrollAppsTV update over this build, since that would remove the patch. The build version is `0.92.1`.

## Changes

- Searches for executable helpers in `/Applications/TrollStoreLite.app`, `/var/jb/Applications/TrollStoreLite.app`, equivalent regular TrollStore paths, and app containers.
- Uses one unique temporary IPA per download, rather than reusing `tmp.install.ipa`.
- Removes its own temporary file after success or failure; existing source lists are preserved.
- Displays download progress, installation state, HTTP/download errors and installer return codes.
- Prevents overlapping downloads and closes for a self-update only after the helper reports success.
- Reports helper termination by signal correctly.
- Resolves process-launch functions at runtime so newer tvOS SDK availability annotations do not break compilation; reports an error if any required function is missing.
- Makes the icon's back layers and top-shelf backgrounds fully opaque at build time, as required by the current asset compiler. Foreground and middle layers remain unchanged.
- Includes a shared Xcode build scheme and fixes the upstream packaging script's `Cp` typo and signing cleanup.

## Checks and limits

Local tests compile and exercise helper discovery for rootful Lite, rootless Lite and regular container installations, as well as install arguments, missing files and helper failures. Compatibility tests compile with the same process-launch functions explicitly marked unavailable, and check missing-symbol errors. The asset preparation tool verifies opaque output and unchanged dimensions. Modified Swift files pass syntax parsing; the Xcode project, scheme, workflow YAML and shell script are checked for valid syntax.

A complete tvOS build and real Apple TV installation have **not** been verified in the authoring environment, which has Command Line Tools but no full Xcode/tvOS SDK. The included GitHub workflow performs the complete build. The patch retains upstream root-helper spawning: your jailbreak and installed entitlements must allow that operation. If it fails, the patched app should now show the helper's return code instead of silently stalling.

For a local build on a Mac with full Xcode and its tvOS platform installed:

```sh
brew install ldid
bash TrollAppsTV/build.command
```

The IPA is written to `TrollAppsTV/build/TrollAppsTV.ipa`.
