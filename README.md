# Crossdrive

The iOS app of CrossDrive Missions: join or volunteer on a mission trip, read
stories from recent missions, pray, and support the work. Built on the shared
packages `mobile-data-layer` and `mobile-design-system`.

## Run it

Needs Xcode 26 or later, with `mobile-data-layer` and `mobile-design-system`
next to this folder.

```bash
open Crossdrive.xcodeproj   # scheme Crossdrive; runs against canned replies (-stub-api)
scripts/setup-hooks.sh      # once per clone: format on commit, checks on push
scripts/check.sh            # secrets, lint, build, tests: the gate for every change
```

There is no backend yet; the base URLs in `Config/*.xcconfig` are
placeholders. No test account exists yet.

## Branches

`main` is released code. `develop` is the integration branch. Work on
`feature/<name>` or `fix/<name>` from `develop` and open a pull request into
`develop`.

## Where things are

```
Crossdrive/App         entry, AppFeatures, container, coordinator, root view
Crossdrive/Core        session, onboarding, deep links, push, connectivity, services
Crossdrive/Features    one folder per screen or flow
Crossdrive/Networking  one API per backend area, DTOs, mappers
Crossdrive/Extensions  Theme+Crossdrive (the only place colours are written)
Config/                one .xcconfig per environment
```
