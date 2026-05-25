# ApexTune

ApexTune is the source-of-truth repository for the current ApexTune desktop optimizer build.

## Current stable build

- Latest local package produced: `ApexTune-v62.60-runtime-orchestration-proof-engine.zip`
- Previous repo package baseline: `ApexTune-v62.49-stability-proof-engine.zip`
- Normal launcher inside package: `ApexTune.vbs`
- Debug launcher inside package: `Launch-ApexTune-Debug.bat`

## Update rule

Future ApexTune work should update this repository instead of creating scattered one-off chat builds. Keep the latest stable package and extracted source files current.

## v62.60 focus

ApexTune v62.60 adds a Runtime page, benchmark proof runner, operation state tracking, safer profile application, game optimizer previews, stronger async worker progress, and updated health-check diagnostics.

## Current priority stack

1. Launch reliability and no duplicate browser/CMD windows.
2. Optimize/Games catalog rendering reliability.
3. Safe Performance Profiles.
4. Performance Doctor scan.
5. Benchmark/proof cards.
6. Restore Vault and rollback verification.
7. Driver Health Center.
8. Repair ApexTune.
9. Updater SHA/ZIP/staging/rollback hardening.
10. Async jobs and UI responsiveness.
11. Runtime orchestration and proof confidence.

## Release notes

The repository currently needs the extracted v62.60 source tree pushed alongside the latest package so future edits can replace files directly instead of stacking ZIP-only builds.