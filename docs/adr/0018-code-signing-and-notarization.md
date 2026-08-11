---
title: "0018 — Code Signing and Notarization for Public Releases"
date: 2026-08-10
status: accepted
---

## Context

[ADR 0017](0017-licensing.md) settled what the binaries may legally be used for
and what notices they must carry. It did not address a separate question that
only arises once the repo is public and the binaries are downloadable by
strangers: **whether the operating system will let them run.**

Today it will not, quietly and badly:

- **macOS.** `game/export_presets.cfg:145` sets `codesign/codesign=1`, which is
  Godot's **Built-in (ad-hoc only)** signing, and `:173` sets
  `notarization/notarization=0`, Disabled. Gatekeeper blocks unsigned,
  un-notarized apps downloaded from unknown sources. The failure is not a
  warning the user can wave through easily — on current macOS it presents as a
  damaged or untrusted application.
- **Windows.** `:92` sets `codesign/enable=false`. An unsigned `.exe` triggers a
  SmartScreen "unknown publisher" interstitial. Users can proceed, but the
  prompt is the strongest possible signal that software is unsafe.
- **Linux.** No OS trust store exists for a plain ELF binary. No signature
  changes how it launches.

This is a first public release of a free, open-source game with no reputation
behind it. A download that the OS actively warns against is worse than no
download — but so is a release that never happens because its prerequisites are
too expensive.

A constraint inherited from ADR 0017: Godot's export templates statically link
the engine, so every binary already carries an MIT notice obligation that the
signing process must not break. Signing seals a bundle — anything added to it
afterwards invalidates the signature. Notices must be in place before signing,
or alongside the artifact rather than inside it.

### Options considered — Windows

Since June 2023 the CA/Browser Forum has required code-signing private keys to
live on FIPS-certified hardware or an HSM. Cheap file-based certificates no
longer exist, which removes the option this project would have taken two years
ago.

| Option | Cost | Verdict |
|---|---|---|
| **Ship unsigned, and say so plainly** | free | **Chosen.** See below. |
| Azure Artifact Signing (formerly Trusted Signing) | ~$9.99/month | Rejected. Investigated in detail; three separate frictions, described below. |
| Traditional OV certificate (Sectigo, DigiCert, SSL.com, Certum) | ~$200–600/year | Rejected on cost and friction. A physical USB token cannot be automated at all; a cloud-HSM variant can, at several times the price. |

Azure Artifact Signing looked like the obvious answer on price and was
investigated first. Three things ruled it out:

1. **It cannot sign from macOS.** Signing goes through SignTool plus a
   Microsoft dlib, with documented prerequisites of Windows 10 1809 or newer,
   Windows 11, or Windows Server 2016 or newer; the official GitHub Action runs
   on Windows runners only. Adopting it would have meant either a Windows VM or
   a `windows-latest` CI job holding signing credentials — directly against the
   "no signing secrets in GitHub" position taken for macOS below.
2. **Identity validation is quoted at 1 to 20 business days**, is portal-only,
   and sources its details from the Azure billing account, whose legal name and
   address must match a government ID exactly. A mistake means filing a fresh
   request. That is an unbounded gate on a release that is otherwise days away.
3. **Public Trust certificates restrict individual developers to the United
   States and Canada** — a narrower list than the one for organisations, and a
   hard eligibility question to have to answer before a first release.

Against that: what signing actually buys on Windows is the removal of one
dismissible interstitial. A standard, non-EV certificate does not even remove
it immediately — SmartScreen reputation accrues over downloads and time, so
early users would likely have seen the warning anyway. Paying a recurring fee
and accepting a multi-week schedule risk to *partially* soften a dismissible
prompt, on the first release of a free game, is a bad trade.

### Options considered — macOS

There is no competitive market: notarization requires an Apple Developer ID
certificate, which requires the **$99/year** Apple Developer Program. The only
real choice is *where* signing runs.

| Option | Verdict |
|---|---|
| **Sign and notarize locally on the product owner's Mac, using Xcode `codesign` and `notarytool`** | **Chosen.** No Apple key material ever enters GitHub, which matters more once the repo is public. Signing folds into the same session as the visual QA pass, which already has to happen on that machine. |
| Sign in CI on `ubuntu-latest` with `rcodesign` | Rejected. Requires exporting the Developer ID certificate as a PKCS#12 and storing it, its password, and the App Store Connect key as repo secrets — a materially larger blast radius for a project that cuts releases rarely. Worth revisiting if release cadence increases. |

Unlike Windows, the macOS spend is not optional in the same sense: without
notarization the build does not present as "warned about", it presents as
broken.

### Options considered — Linux

| Option | Verdict |
|---|---|
| **Detached OpenPGP signature over a SHA-256 manifest covering all artifacts** | **Chosen.** Free, standard practice, one signature covers every platform, and it gives Windows users a compensating control for the missing Authenticode signature. |
| Per-file detached signatures | Rejected as redundant. Six files, six signatures, six verification commands, no additional assurance over signing the manifest. |
| Checksums with no signature | Rejected. A checksum published beside the file it describes proves only that the download completed, since anyone who can replace the binary can replace the checksum. |
| Nothing | Rejected. It costs one command. |

## Decision

Ship `v0.1.0` with:

- **macOS — signed and notarized.** Apple Developer Program, a Developer ID
  Application certificate, Godot's *Xcode codesign* and *Xcode notarytool*
  export options, signed and notarized on the product owner's Mac. Export
  target changes from `.zip` to `.dmg` so the notarization ticket can be
  stapled and so `LICENSE` and `THIRD-PARTY-NOTICES.md` travel inside the disk
  image.
- **Linux — a detached OpenPGP signature** over a `SHA256SUMS.txt` manifest
  covering every published artifact on every platform. The public key is
  committed to the repo, uploaded to a keyserver, and its fingerprint printed
  in `README.md` and on the website.
- **Windows — unsigned, deliberately and visibly.** Godot's Windows signing
  stays disabled. The SmartScreen behaviour is documented in the release note
  and next to the website's download button, together with the checksum
  verification steps.
- Signing is a **release** path, not a CI path. The existing `ubuntu-latest`
  export job stays exactly as it is and continues to run unsigned on every
  push.

Procedure lives in [signing-runbook.md](../signing-runbook.md).

## Consequences

### Positive

- A first-time downloader on macOS sees no warning at all.
- **No signing credential of any kind is stored in GitHub.** With the Windows
  route dropped, this is true by construction rather than by policy: there is
  nothing left that a CI job would need a secret for. That is a real security
  property of a public repo, not just a convenience.
- **Total recurring cost is $99/year**, and the release schedule depends on no
  third-party review queue longer than Apple enrolment.
- Every artifact on every platform gets an integrity and authorship signal,
  including the Windows build that carries no platform signature.
- The `.zip` → `.dmg` change closes the standing macOS notice gap recorded in
  the 2026-08-09 log, where `LICENSE` and `THIRD-PARTY-NOTICES.md` landed
  beside the archive rather than with the app.
- The macOS binary finally reports its own version: `application/short_version`
  and `application/version` are set in the same pass, so a downloaded build can
  be traced to a tag.

### Negative / Trade-offs

- **Windows users get a SmartScreen "unknown publisher" interstitial**, and
  some will not proceed past it. Some antivirus engines additionally flag
  unsigned Godot executables heuristically. This is the accepted cost, and the
  mitigation is honesty rather than technology: warn about the warning.
- **The GPG signature does not help most users.** It is trust-on-first-use — it
  proves the file matches a key, and the key's authenticity rests on the same
  channel as the download. It is meaningful to a distro packager or a careful
  user, and close to decorative for everyone else.
- **A recurring $99/year with no revenue.** Cancellable; letting it lapse means
  notarization of *new* builds stops working. Already-notarized, stapled builds
  keep validating.
- **Signing is manual.** Every release requires a person at a Mac. Releases get
  slower, and the procedure is only as good as the runbook.
- **The GPG private key is a new long-lived secret to look after**, along with
  its revocation certificate. A lost key that cannot be revoked is worse than
  no key.

### Neutral / Follow-on work

- Build-review **V2** (gate the Windows and macOS packs, not just Linux) should
  land before or with this. A checksum attests to the integrity of contents
  that nothing has verified.
- The `v0.1.0` release note must state which artifacts are signed, which are
  not, how to verify, and what Windows users will see.
- `README.md` and the website download section need the key fingerprint and the
  unsigned-Windows note.
- Revisit Windows signing if Windows becomes a meaningful share of downloads,
  if the project acquires a legal entity, or if a platform that handles signing
  (itch.io app, Steam) becomes the primary Windows channel. Supersede this ADR
  rather than quietly changing practice.
- Revisit CI-side macOS signing with `rcodesign`, or a `macos-latest` runner, if
  release cadence rises to the point where manual signing is the bottleneck.
  Both reintroduce stored credentials — re-weigh that deliberately.
