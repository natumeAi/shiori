# Brotli static dictionary

`dictionary.bin` is the Brotli static dictionary (RFC 7932, Appendix A),
used by the pure-Dart WOFF2 decoder. It is data only; no Brotli code is
vendored.

- Source: https://github.com/google/brotli, file `c/common/dictionary.bin`
- Tag `v1.1.0`, commit `ed738e842d2fbdf2d6459e39267a633c4a9b2f5d`
- Size: 122784 bytes
- SHA-256: `20e42eb1b511c21806d4d227d07e5dd06877d8ce7b3a817f378f313653f35c70`
- Cross-check: the same 122784 bytes appear verbatim (offset 12096) in the
  locally installed Brotli 1.2.0 `libbrotlicommon.dll` shipped with Git for
  Windows.
- Licence: MIT, see `LICENSE` (SHA-256
  `3d180008e36922a4e8daec11c34c7af264fed5962d07924aea928c38e8663c94`).
  The notice must be added to the app's licence registry (S4c handoff).
- Downloaded 2026-10-29 with owner approval.

`.gitattributes` marks `third_party/**` binary so line endings stay exact.
