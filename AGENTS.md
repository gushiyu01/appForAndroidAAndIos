Repo notes

- This repo intentionally stores only Dart code, templates, and CI; Android/iOS projects are generated in CI with `flutter create`.
- Native behavior is injected from files under `tool/templates` by `tool/prepare_platforms.py`.
- CI uses Flutter 3.44.9 because the current plugin set is validated against that version.
- Mobile pages live in `lib/pages`; native motion channels are consumed by `lib/services/motion_service.dart`.
- Before pushing, run `python tool/validate_templates.py`; full checks stay in GitHub Actions.
