---
title: "Signing Runbook — Signed Release Binaries"
date: 2026-08-10
status: active
---

## Purpose

How to produce signed release binaries for Wildlife Crossing: a signed and
notarized macOS build, GPG-signed checksums covering every artifact, and a
deliberately unsigned Windows build.

The decision this implements is recorded in
[ADR 0018](adr/0018-code-signing-and-notarization.md). Read it first if you want
the reasoning; this file is the procedure.

This runbook does **not** replace [push-runbook.md](push-runbook.md). That
covers committing and pushing; this covers what happens to the binaries after
CI has built them.

## Scope at a glance

| Platform | What ships | Mechanism |
|---|---|---|
| **macOS** | Signed **and** notarized `.dmg` | Apple Developer ID + `notarytool`, on Brent's Mac |
| **Linux** | Signed checksums, unsigned binary | Detached OpenPGP signature over `SHA256SUMS.txt` |
| **Windows** | **Unsigned** `.exe`, covered by signed checksums | None — deliberate, see ADR 0018 |

Only one paid dependency: the **Apple Developer Program, $99 USD/year**.
Everything else costs nothing.

> **Two things are worth understanding before you start.**
>
> **These are different kinds of signature.** Apple's is an *OS trust*
> mechanism: it changes whether macOS will run the binary. GPG is an
> *integrity and authorship* mechanism: it lets someone who has your public key
> prove the file came from you unmodified. GPG will not stop a single OS
> warning on any platform. It is still worth doing — it is the only integrity
> signal Linux users get — but it is not a substitute for platform signing, and
> the release note should not imply that it is.
>
> **Apple enrolment takes a few days.** It is the only calendar-time gate left.
> Start it first; the export verification and visual QA pass can run in
> parallel against unsigned builds.

---

# Part A — macOS: sign and notarize on your Mac

Everything in Part A runs on Brent's Mac. No key material goes near GitHub.

## A1. Enrol in the Apple Developer Program

<https://developer.apple.com/programs/>. **$99 USD/year.** Enrolment is not
instant; identity checks can take a few days.

## A2. Create a Developer ID Application certificate

In Xcode: **Settings → Accounts → [your Apple ID] → Manage Certificates → + →
Developer ID Application**. Or generate it from
<https://developer.apple.com/account/resources/certificates>.

It must be a **Developer ID Application** certificate. An "Apple Development"
or "Mac App Distribution" certificate will sign, and will then fail
notarization — this is the single most common wasted afternoon in this process.

Note two values you will need:

```bash
security find-identity -v -p codesigning
```

The output line is your **signing identity** — the full string, e.g.
`Developer ID Application: Brent Humphries (ABCDE12345)`. The parenthesised
value is your **Team ID**.

## A3. Accept the Xcode licence

Godot shells out to `codesign` and `notarytool`; both refuse to run until the
licence is accepted.

```bash
xcode-select --install
```

```bash
sudo xcodebuild -license accept
```

## A4. Create an App Store Connect API key

<https://appstoreconnect.apple.com/access/integrations/api>. Create a key with
the **Developer** role and download the `.p8` — Apple lets you download it
exactly once.

Keep three values: the **Issuer ID** (a UUID), the **Key ID**, and the path to
the `.p8` file. Store the `.p8` outside the repo.

An Apple ID plus an app-specific password also works, but the API key is
revocable independently of your Apple ID and does not break when you change
your password.

## A5. Configure the macOS export preset

Open the project in Godot and go to **Project → Export → macOS**. Set:

| Section | Option | Value |
|---|---|---|
| Application | Short Version | `0.1.0` |
| Application | Version | `0.1.0` |
| Code Signing | Codesign | **Xcode codesign** |
| Code Signing | Identity | the full string from A2 |
| Code Signing | Apple Team ID | the Team ID from A2 |
| Entitlements | Debugging | **off** |
| Notarization | Notarization | **Xcode notarytool** |

Current state of `game/export_presets.cfg`, for comparison — every one of these
needs to change:

- `codesign/codesign=1` (`:145`) — that is **Built-in (ad-hoc only)**, not real
  signing. Xcode codesign is `3`.
- `notarization/notarization=0` (`:173`) — Disabled. Xcode notarytool is `2`.
- `application/short_version=""` (`:138`) and `application/version=""` (`:139`)
  — empty, so a downloaded build cannot be traced back to a tag.
  (`game/project.godot:17` already carries `config/version="0.1.0"`; these two
  fields are separate and feed the macOS `Info.plist`.)
- `codesign/entitlements/debugging=false` (`:161`) — already correct.
  Notarization rejects a build that has the debugging entitlement.
- `application/icon=""` (`:133`) — still empty. v0.1.0 ships the default Godot
  icon; that is a known and recorded first-build limitation, not a signing
  problem.

> ### Do not type your API key into the export dialog
>
> **`game/export_presets.cfg` is tracked in git.** Godot writes whatever you
> type in the export UI straight into that file, and the repo is about to go
> public. Pass the notarization credentials as environment variables instead —
> Godot reads these and they override the preset:
>
> ```bash
> export GODOT_MACOS_NOTARIZATION_API_UUID="<issuer id>"
> ```
>
> ```bash
> export GODOT_MACOS_NOTARIZATION_API_KEY_ID="<key id>"
> ```
>
> ```bash
> export GODOT_MACOS_NOTARIZATION_API_KEY="/absolute/path/to/AuthKey_XXXX.p8"
> ```
>
> The signing *identity* and Team ID are fine to commit — they are public
> information printed into every binary you ship. The API key is not.
>
> Run `git diff game/export_presets.cfg` before committing, every time. This is
> the one file in the repo where a UI click can leak a secret.

## A6. Export to a DMG, not a ZIP

Change the macOS preset's export path from `wildlife-crossing.zip` to
`wildlife-crossing.dmg`. Two reasons, and the second one closes a gap that has
been open since the licensing session:

1. **You cannot staple a notarization ticket to a `.zip`.** Stapling attaches
   the ticket to the artifact so the app validates without a network round-trip
   on first launch. A `.dmg` accepts a staple; a `.zip` does not. (The
   alternative is to unzip, staple the `.app`, and re-zip with `ditto` — an
   extra two steps that are easy to get wrong.)
2. **The `.zip` export is why `LICENSE` and `THIRD-PARTY-NOTICES.md` land
   outside the bundle** — flagged in the 2026-08-09 log as the narrowed-but-open
   macOS notice gap. A DMG carries them in the image alongside the `.app`.

DMG export is only supported when exporting from macOS, which is exactly where
release builds now happen.

> **Ordering rule:** anything that goes *inside* the `.app` must be there
> before signing. Modifying a bundle after it is signed invalidates the
> signature. Put the notices in the DMG next to the app, never into
> `Contents/Resources` after the fact.

Then export:

```bash
cd ~/wildlife-crossing/game
```

```bash
godot --headless --export-release "macOS" ../builds/wildlife-crossing-macos/wildlife-crossing.dmg
```

Godot signs during export and submits for notarization. Notarization is a
round-trip to Apple and usually takes minutes.

## A7. Verify — do not trust the export log

```bash
codesign --verify --deep --strict --verbose=2 /Volumes/.../Wildlife\ Crossing.app
```

```bash
xcrun notarytool history --key "$GODOT_MACOS_NOTARIZATION_API_KEY" --key-id "$GODOT_MACOS_NOTARIZATION_API_KEY_ID" --issuer "$GODOT_MACOS_NOTARIZATION_API_UUID"
```

If a submission came back `Invalid`, get the reason — the log is specific and
usually names the offending file:

```bash
xcrun notarytool log <submission-id> --key "$GODOT_MACOS_NOTARIZATION_API_KEY" --key-id "$GODOT_MACOS_NOTARIZATION_API_KEY_ID" --issuer "$GODOT_MACOS_NOTARIZATION_API_UUID"
```

Staple the ticket, then confirm it took:

```bash
xcrun stapler staple builds/wildlife-crossing-macos/wildlife-crossing.dmg
```

```bash
xcrun stapler validate builds/wildlife-crossing-macos/wildlife-crossing.dmg
```

Finally, the check that actually matters — Gatekeeper's own verdict:

```bash
spctl -a -vvv -t install builds/wildlife-crossing-macos/wildlife-crossing.dmg
```

## A8. The real acceptance test

Download the DMG from the published GitHub Release, on a Mac that has never
had this project on it, and open it. **No Gatekeeper warning at all** is the
pass condition. Anything less — "unidentified developer", a right-click-to-open
workaround, a quarantine prompt — means it isn't done.

Record the result in the daily log alongside the visual QA findings. The same
session covers both.

---

# Part B — Linux: signed checksums

Linux has no equivalent of Gatekeeper or Authenticode: there is no OS trust
store that a plain ELF binary can be signed into, and no signature will change
how the binary launches. What a Linux user *can* do is verify that the file
they downloaded is byte-for-byte the file you published. That is what this part
provides — a SHA-256 manifest covering **every** artifact, with a detached
OpenPGP signature over the manifest.

Signing the manifest rather than each binary is deliberate: one signature
covers all platforms, and verification is two commands instead of six.

## B1. Create a signing key — once, ever

Skip to B2 if you already have one you're happy to use for this.

```bash
gpg --quick-generate-key "Brent Humphries <brent.humphries@gmail.com>" ed25519 sign 3y
```

Note the fingerprint it prints. Then generate a revocation certificate
immediately and store it somewhere you will still have if the key is lost:

```bash
gpg --output ~/wildlife-crossing-revoke.asc --gen-revoke <FINGERPRINT>
```

> **Back up the private key and the revocation certificate off this machine.**
> A lost signing key is not a catastrophe — you publish a new one — but a lost
> key you cannot *revoke* means you can never tell users the old one is dead.

## B2. Publish the public key

Export it:

```bash
gpg --armor --export <FINGERPRINT> > wildlife-crossing-signing-key.asc
```

Then make it findable through more than one channel, because a key delivered
over the same channel as the file it signs proves very little:

1. Commit `wildlife-crossing-signing-key.asc` to the repo root.
2. Upload it to a keyserver: <https://keys.openpgp.org/upload>.
3. Print the **full fingerprint** in `README.md` and on the website's download
   section.

## B3. Generate and sign the manifest

Run this after every artifact for the release is built and, for macOS, already
notarized and stapled — a stapled DMG has different bytes from an unstapled
one, so checksum last.

```bash
cd ~/wildlife-crossing/builds
```

```bash
find . -type f \( -name '*.dmg' -o -name '*.exe' -o -name '*.pck' -o -name 'wildlife-crossing.x86_64' \) -print0 | xargs -0 shasum -a 256 > SHA256SUMS.txt
```

```bash
cat SHA256SUMS.txt
```

Read it before signing. You are attesting to these exact files; a stale
artifact from a previous build sitting in `builds/` gets signed just as
happily as a current one.

```bash
gpg --armor --detach-sign SHA256SUMS.txt
```

That writes `SHA256SUMS.txt.asc`. Attach **both** files to the GitHub Release.

## B4. Verify, as a user would

```bash
gpg --verify SHA256SUMS.txt.asc SHA256SUMS.txt
```

```bash
shasum -a 256 -c SHA256SUMS.txt
```

The first proves the manifest is yours; the second proves the binaries match
the manifest. Put both commands in the release note — an integrity mechanism
nobody knows how to use is decoration.

---

# Part C — Windows: deliberately unsigned

**Wildlife Crossing does not sign its Windows binaries.** This is a recorded
decision, not an oversight — see
[ADR 0018](adr/0018-code-signing-and-notarization.md) for why the available
options were all worse than shipping unsigned and saying so plainly.

## C1. Leave Godot's Windows signing off

`game/export_presets.cfg:92` has `codesign/enable=false`. **Keep it false.**
Nothing in the Windows export path changes.

## C2. Say so where users will actually see it

An unsigned `.exe` triggers a SmartScreen "Windows protected your PC"
interstitial with an **unknown publisher**. Users can proceed via *More info →
Run anyway*, but only if they trust you enough to look for that link. Some
antivirus engines also heuristically flag unsigned game executables; false
positives on Godot builds are not unusual.

Three places must carry this, in the user's own words rather than as a
technical footnote:

1. **`docs/release-notes/v0.1.0.md`** — a "Known issues" entry stating that the
   Windows build is unsigned, what the warning looks like, and how to get past
   it.
2. **The website download section** — the same, next to the download button,
   not buried.
3. **The SHA-256 checksum** — Windows users get the same manifest and signature
   as everyone else (Part B). It is the compensating control, and it only helps
   if it is offered alongside the warning.

Being direct about this is the point. A user who was warned that a warning is
coming trusts you more than one who hits it cold.

## C3. When to revisit

Reopen the decision if any of these become true:

- Windows downloads are a meaningful share of users and the interstitial is
  visibly costing installs.
- The project acquires a legal entity, which makes organisation-level
  certificate options available and cheaper per-release.
- A distribution platform that handles signing for you (itch.io app, Steam)
  becomes the primary Windows channel — at which point this stops being your
  problem.

Superseding ADR 0018 with a new ADR is the mechanism; don't just start signing.

---

# Part D — Wiring it into the release

1. **Keep the existing CI export exactly as it is.**
   `.github/workflows/ci.yml` builds all three targets on `ubuntu-latest` and
   runs `check_pck_contents.py` and `smoke_boot.sh` on every push. Signing is a
   *release* path, not a *CI* path. Nothing in this runbook belongs in that
   workflow.
2. **No signing secret ever enters GitHub.** Both keys — the Apple certificate
   and the GPG private key — stay on the Mac. This is now true by construction,
   with the Windows route gone: there is nothing left that a CI job would need
   credentials for. Keep it that way.
3. **Gate the other two platforms' packs.** Build-review V2 is still open: the
   pck gate and smoke boot run on the Linux binary only. Publishing a checksum
   for a Windows `.exe` that no gate has ever checked attests to the integrity
   of contents nobody verified.
4. **Checksum last, after stapling.** See B3.
5. **State the signing status in the release note.** Which artifacts are
   signed, which are not, and how to verify. `docs/release-notes/v0.1.0.md`
   already has to carry the Bow-Valley-only scope and the placeholder-art
   limitation; this is one more section.

---

## Suggested order of work

| | Do this | Blocks on |
|---|---|---|
| 1 | Enrol in the Apple Developer Program (A1–A2) | nothing — a few days |
| 2 | Export and verify `HEAD`, unsigned (build-review B1) | nothing |
| 3 | Visual + audio QA pass on that build (build-review C3) | 2 |
| 4 | Create and publish the GPG signing key (B1–B2) | nothing |
| 5 | macOS signing config and a signed test export (A5–A7) | 1 |
| 6 | Write the unsigned-Windows copy for the release note and website (C2) | nothing |
| 7 | Cut v0.1.0: build, notarize, checksum, sign the manifest, publish | 3, 5, 6 |

Only step 5 waits on anything external, and only for days. Steps 2, 3, 4 and 6
can all start now.

---

## Known gotchas

- **`export_presets.cfg` is tracked and Godot writes secrets into it.** Use the
  `GODOT_MACOS_NOTARIZATION_*` environment variables and diff the file before
  every commit. See A5.
- **An "Apple Development" certificate signs fine and fails notarization.** It
  must be **Developer ID Application**. See A2.
- **The `Debugging` entitlement blocks notarization.** Currently `false` at
  `export_presets.cfg:161` — leave it that way.
- **You cannot staple a ticket to a `.zip`.** See A6.
- **Never modify a signed bundle.** Adding a licence file to `Contents/` after
  signing silently invalidates the signature; the failure surfaces on a user's
  machine, not yours.
- **Checksum after stapling, not before.** Stapling rewrites the DMG.
- **Stale files in `builds/` get signed too.** Read `SHA256SUMS.txt` before
  signing it. See B3.
- **GPG signatures do not suppress OS warnings** on any platform. They prove
  authorship and integrity to someone who already has your key. Don't let the
  release note blur the two.

---

## Related

- [ADR 0018 — code signing and notarization](adr/0018-code-signing-and-notarization.md)
- [ADR 0017 — licensing](adr/0017-licensing.md), which established the notice
  obligations these binaries carry
- [push-runbook.md](push-runbook.md) — committing and pushing
- [export-setup.md](export-setup.md) — export presets and the pck gate
- [Godot: Exporting for macOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)
- [Godot: Exporting for Windows](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)
