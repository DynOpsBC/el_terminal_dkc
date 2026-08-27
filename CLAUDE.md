# BCWMSApp Agent Rules

- Create and modify files only inside this repository.
- Do not initialize git or commit unless explicitly requested.
- AL objects must use prefix `DOPSWHS` and the baseline object ID range `72000-72099`.
- Treat `72000-72099` as the Sprint 0 baseline; document any future pressure to expand to `72000-72499`.
- Target Business Central platform `24.0.0.0`, runtime `13.0`, application `24.0.0.0`.
- Test sandbox URL: `https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox?company=Demo%20Business%20Central`.
- Sandbox tenant: `7fa2357e-26f2-4174-8e16-a713981356b8`, environment `CustomerSandbox`, company `Demo Business Central`.
- Source language is `en-US`; supported translations are `tr-TR` and `de-DE`.
- Do not compile AL on macOS. Packaging and AppSourceCop validation require Windows AL tooling.
- Do not run Gradle unless an Android SDK is configured.
- Web uses React 19, Vite 5, TypeScript 5.6.
- Android uses Kotlin `2.0.21`, AGP `8.6.1`, minSdk `26`, targetSdk `35`, application ID `com.dynops.bcwms`.
- Azure Functions push relay uses TypeScript.

## Validation Commands

Run only when the required toolchain is available:

```bash
cd android && ./gradlew lintDebug testDebugUnitTest assembleDebug
cd web && pnpm typecheck && pnpm build
cd push-relay && pnpm build
```

