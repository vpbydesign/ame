# AME Release Checklist

The release manager MUST complete every item below before tagging any
`vX.Y` release. Missing or skipped items invalidate the release.

For the discipline rationale, see
[`specification/v1.0/regression-protocol.md`](specification/v1.0/regression-protocol.md).

---

## Pre-release Gate

Copy this checklist into the release PR description and check off each item.

### 1. Reference implementation tests

- [ ] `./verify-bugs.sh` — all 6 audit suites pass (Kotlin parser, Compose,
  Swift parser, SwiftUI render, Flutter parser, Flutter UI). The script is
  the single source of truth for which suites the project considers
  normative; new runtimes are added by appending a `run_suite` invocation.

### 2. Conformance suite

- [ ] `./conformance/check-parity.sh` — zero diffs against expected JSON
- [ ] All runtime CLIs run independently per fixture (kotlin, swift,
  flutter) via the multi-runtime `conformance/check-parity.sh`, and each
  shows zero diffs

### 3. Audit regression suite

- [ ] `./verify-bugs.sh` — every audit regression test in its expected
  state. REAL bugs that have been fixed now PASS; NOT REAL phantom
  guards still PASS; any new bug discovered since last release has been
  added with a row in `AUDIT_VERDICTS.md`.
- [ ] [`AUDIT_VERDICTS.md`](AUDIT_VERDICTS.md) — up to date with all bug
  verdicts including any verified or refuted since the last release.

### 4. Cross-runtime parity

Cross-runtime serialization parity is enforced by the conformance suite
(§2 above). Per the standards-design pattern (JSON Schema, gRPC, h2spec,
Web Platform Tests), generative/fuzz testing is a per-runtime
implementation concern, not a project-level release gate. Individual
runtime implementations may add internal property-based or fuzz testing
as their own quality practice.

### 5. Spec/version coherence

- [ ] `specification/v1.0/README.md` — version line matches the release
  tag (v1.1, v1.2, …).
- [ ] All spec documents in `specification/v1.0/` referenced from the
  README are present and link-checked.

### 6. Conformance changelog (BREAKING-CONFORMANCE check)

- [ ] If any `BREAKING-CONFORMANCE`-labeled PR has merged since the last
  tag:
  - [ ] The release notes list every affected `.expected.json` file
  - [ ] The release notes describe the semantic change in plain language
  - [ ] The release version bump is **at minimum** a minor bump
    (1.1 → 1.2). A major bump (1.x → 2.0) is required if the change
    breaks any documented spec promise (e.g., changes the `_type`
    discriminator, removes a primitive, reorders required arguments).
  - [ ] Implementations advertising AME conformance have been notified
    via the announcements channel (e.g., GitHub Discussions).

### 7. Public artifacts

- [ ] Release notes drafted in the GitHub release UI
- [ ] Conformance results re-published if the project hosts a public
  conformance dashboard
- [ ] Repository [README.md](README.md) updated if the conformance level
  or test counts changed

### 8. Manual visual smoke test

- [ ] Render `examples/v1.1-showcase.ame` on iOS simulator (latest
  supported version) and confirm no visible regressions
- [ ] Render `examples/v1.1-showcase.ame` on Android emulator (latest
  supported version) and confirm no visible regressions
- [ ] Cross-compare iOS vs Android screenshots for any unintended
  rendering differences

### 9. Sign-off

- [ ] Release manager signature: `____________________`
- [ ] Date: `____________________`
- [ ] Tag: `vX.Y`

---

## What invalidates a release

A release MUST be retracted (and the tag deleted, if pushed) if any of
the following are discovered after publication:

- An audit regression test was failing at the time of release (the gate
  was bypassed)
- A `BREAKING-CONFORMANCE` change shipped without the release notes
  mentioning it
- A conformance `.expected.json` was modified and never regenerated
  (parity script would have failed)
- Any test was disabled, skipped, or commented out to make the gate pass

Retractions are documented in `specification/v1.0/errata.md` (added when
needed; not required to exist preemptively).

---

## What this checklist does NOT cover

- Performance regressions (covered by `benchmarks/` separately)
- Documentation typos (covered by ongoing PR review)
- Third-party implementation conformance (each implementation runs its
  own gate)

These are tracked in their own processes; this checklist is the AME
project's own release discipline only.
