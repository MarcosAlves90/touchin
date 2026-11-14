# Rounded workspace navigation goldens

These four reference images capture the workspace navigation after the rounding
change in PR #137 (`fix/round-remaining-corners`): an 8 px radius on the brand
mark and 16 px on the trailing corners of the mobile drawer.

They are the original `*_testImage.png` artifacts from the **Ubuntu / Flutter
3.47.2** canonical golden job in [CI run 43644262839](https://github.com/MarcosAlves90/touchin/actions/runs/43644262839),
generated from commit `2b4b8cfa813c67ed7e062710537bbe12846880fa`.
Their differences from the historical images in `docs/validation/issue-119/`
were independently checked pixel by pixel: all differing pixels are confined
to the intended brand and drawer corners; none occur elsewhere.

The historical images and their provenance are retained unchanged. The active
golden test now compares against this set, preserving exact-pixel comparison
on the canonical CI runner.

| Snapshot | Viewport | SHA-256 |
| --- | --- | --- |
| `desktop-light.png` | 1440 × 900 | `bd32207a5f2f411947d0cf46362ea893157962df2eba5e289a6a563be26a4a37` |
| `desktop-dark.png` | 1440 × 900 | `de1234eed75303ec5d7aa2bc2cfd05a0858b49fac13bd7fe275d8bfde1281182` |
| `mobile-light.png` | 390 × 844 | `8544530fad47f0820e62df4d4d44a396eaa949df49a6c11155af88f0b822b` |
| `mobile-dark.png` | 390 × 844 | `1ed4282989aa34f05e20c339d79e676a2ab7850b4c6fd2956efe9f362af7cbd8` |

To compare the four images from `frontend/` with Flutter 3.47.2 on Ubuntu:

```sh
flutter test --tags canonical-golden
```

Do not update these images in a different renderer or SDK version. Review any
future differences before intentionally updating the baseline.
