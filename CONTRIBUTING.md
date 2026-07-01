# Contributing

Thanks for your interest in improving `flutter_network_throttler`!

## Getting set up

```bash
git clone https://github.com/firaskola/flutter_network_throttler.git
cd flutter_network_throttler
flutter pub get
```

## Before opening a pull request

Please make sure the following all pass:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --exclude-tags "golden || screenshot"
```

- Add or update tests for any behaviour you change.
- Keep public APIs documented with `///` doc comments.
- Update `CHANGELOG.md` under an "Unreleased" or new version heading.

### Golden & screenshot tests

The panel has a **golden** regression test and a **screenshot** generator. They
load fonts checked into `test/fonts/` (Roboto, Apache-2.0), so they run on any
platform.

```bash
# Run the golden test:
flutter test --tags golden

# After an intentional UI change, regenerate the baseline:
flutter test --tags golden --update-goldens

# Refresh the README image (doc/panel.png):
flutter test --tags screenshot
```

A tolerant golden comparator (`test/flutter_test_config.dart`) absorbs a couple
of percent of cross-platform anti-aliasing noise. If goldens still differ on
your machine after an unrelated change, regenerate them and mention it in the
PR.

## Reporting bugs

Open an issue on the
[issue tracker](https://github.com/firaskola/flutter_network_throttler/issues) with
a clear description and, ideally, a minimal reproduction.

## Code of conduct

Be respectful and constructive. We follow the spirit of the
[Contributor Covenant](https://www.contributor-covenant.org/).
