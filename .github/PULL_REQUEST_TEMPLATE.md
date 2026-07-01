## What & why

Briefly describe the change and the motivation.

Fixes #<!-- issue number, if any -->

## Type of change

- [ ] Bug fix (non-breaking)
- [ ] New feature (non-breaking)
- [ ] Breaking change
- [ ] Docs / tests / tooling only

## Checklist

- [ ] `dart format --output=none --set-exit-if-changed .` passes
- [ ] `flutter analyze` is clean
- [ ] `flutter test --exclude-tags "golden || screenshot"` passes
- [ ] Added/updated tests for the change
- [ ] Public APIs documented with `///`
- [ ] Updated `CHANGELOG.md`
- [ ] If the panel UI changed, regenerated goldens
      (`flutter test --tags golden --update-goldens`)
