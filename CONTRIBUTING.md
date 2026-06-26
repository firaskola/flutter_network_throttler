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
flutter test
```

- Add or update tests for any behaviour you change.
- Keep public APIs documented with `///` doc comments.
- Update `CHANGELOG.md` under an "Unreleased" or new version heading.

## Reporting bugs

Open an issue on the
[issue tracker](https://github.com/firaskola/flutter_network_throttler/issues) with
a clear description and, ideally, a minimal reproduction.

## Code of conduct

Be respectful and constructive. We follow the spirit of the
[Contributor Covenant](https://www.contributor-covenant.org/).
