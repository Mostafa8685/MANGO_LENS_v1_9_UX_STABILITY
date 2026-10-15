# MANGO LENS v1.8 — PRO FEATURES

Arabic-first Flutter app for product recognition, researched price comparisons, rarity evidence, and seller calculations.

## Included in this build
- Fixed the Dart constant-list issue that previously stopped compilation (`DropdownMenuItem` labels use `_t(...)` dynamically).
- Orange Material 3 UI, Arabic RTL and English option, light/dark themes.
- Camera/gallery product image input.
- Gemini/OpenAI provider settings and one-request analysis flow, with local result cache, cooldown, and API usage counters.
- Structured product report, offer table, source links, Amazon Egypt fallback search, and currency selection.
- Price-history honesty field: the model must say when real historical observations are unavailable instead of inventing a chart or past prices.
- Rarity score and confidence fields, with evidence/uncertainty guidance.
- Saved analysis history and local favorites/bookmarks.
- Compare two saved reports side-by-side (price summary, rarity, specifications).
- Copy/export report text using Android clipboard.
- Seller profit calculator runs locally without AI calls.
- Home quick tools for history, comparison, prices, rarity, export, and calculator.
- No price-alert feature is included, per the project requirements.

## Known limitations
- This is a source ZIP, not a verified APK. Flutter SDK/build tools were not available in the editing environment, so run GitHub Actions to verify compilation before using it.
- The source does not contain a giant gray rectangle or a banner-ad placeholder widget. If that rectangle remains in the installed app, confirm the build workflow is compiling this exact commit/archive and uninstall the old APK before installing the new build; it may be from a different/older source or a native/build artifact.
- Historical prices are not invented. The app only reports what the model can substantiate; a real trend chart requires collecting verified prices over time from a reliable source.
- Report export currently copies the report text to the clipboard; direct PDF file generation and native sharing need a separately tested export dependency.
- Barcode recognition, automatic counterfeit verification, live FX conversion, and scheduled price alerts are not claimed as implemented.
- Secure local storage helps protect keys at rest but does not make embedded user-supplied API keys impossible to extract from a distributed APK. A public commercial service should proxy requests through a backend with server-side secrets and quotas.

## Build
1. Upload the contents of this archive to the GitHub repository root.
2. Run the repository's GitHub Actions workflow.
3. If it fails, share the complete first Dart/Gradle error and workflow log for a targeted fix.

Version: `1.8.0+9`

## v1.9.0 — UX, accessibility, and stability update
- First-launch welcome dialog with a brief onboarding message.
- Analysis status text cycles through preparation, identification, checking, and report preparation stages. These are UI progress stages; the AI provider does not stream partial sections.
- Report sections fade in sequentially after the response is received.
- Unified friendly error messages and a visible Retry action.
- Product image can be enlarged with InteractiveViewer.
- Product comparison table scrolls horizontally; report setup controls adapt to narrow screens.
- Dedicated Privacy and About/version pages, accessible from Settings and the Home footer.
- App version updated to 1.9.0+10.

### Testing note
This source was reviewed and packaged, but a Flutter SDK was not available in the editing environment, so an APK build and real-device performance test have not been run. Run the repository GitHub Actions workflow and test on a lower-memory Android device before release.
