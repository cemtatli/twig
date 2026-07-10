# Onboarding Wizard — Tasarım

**Tarih:** 2026-07-10
**Durum:** Onaylandı, implementasyona hazır

## Amaç

İlk açılışta kullanıcıyı JSON'a düşürmeden kuruluma yönlendiren 3 adımlı sihirbaz: scan root seçimi + kurulu editör/terminal seçimi. Atlanabilir, Ayarlar'dan tekrar açılabilir.

## Mevcut durum

- `ConfigStore.load` config yoksa `Config.default` yazar (ilk açılış tespiti için ayrı flag yok).
- `InstalledApps.installed(_:)` kurulu terminal/editörleri tespit ediyor (auto-detect hazır).
- `AppState.addReposViaPanel()` Finder ile scan root/repo ekliyor.
- `MenuContentView` boş-durum ("No repositories") gösteriyor ama yönlendiren onboarding yok.

## Kapsam dışı (YAGNI)

Paket-yöneticisi adımı, tema seçimi, animasyonlu geçiş, ayrı onboarding metinleri (mevcut L10n + kısa yeni anahtarlar yeterli).

---

## Bölüm 1 — Tetik & config

### Config

```swift
public var onboardingCompleted: Bool   // default false
```
Resilient decode (`decodeIfPresent ... ?? false`), `CodingKeys`, `Config.default`'ta `false`, init'e `onboardingCompleted: Bool = false`.

### Tetik

`MenuContentView.body`'ye `.overlay` — `!state.config.onboardingCompleted` iken tam-pencere `OnboardingView` (canvas arka planı, altındaki UI'ı kapatır).

### Bitir / Atla

- **Bitir (3. adım):** seçilen `editorApp`/`terminalApp` yazılır, `onboardingCompleted = true`, `saveConfig()`.
- **Atla (her adımda):** seçim uygulanmadan `onboardingCompleted = true` + `saveConfig()` (varsayılanlar kalır).

### Tekrar aç

Ayarlar'a bir satır/buton: "Onboarding'i tekrar çalıştır" → `config.onboardingCompleted = false` + `saveConfig()`. Overlay yeniden görünür.

---

## Bölüm 2 — Wizard (3 adım)

Yeni `Sources/Twig/Views/OnboardingView.swift`. `@EnvironmentObject state`, `@State step: Int` (0..2). Üstte ilerleme noktaları, altta Geri / İleri (son adımda "Bitir"), sağ üstte "Atla".

1. **Hoş geldin** — `TwigWordmark` + tagline + kısa açıklama metni. İleri.
2. **Scan root** — "Finder'dan seç" butonu (`state.addReposViaPanel()`), seçili `scanRoots`/`manualRepos` listelenir. `~/Dev` config.default'tan zaten dolu. Geri / İleri.
3. **Editör & Terminal** — iki seçici (`PillTabBar` veya menü) `InstalledApps.installed(InstalledApps.editors)` / `.terminals`'tan; ilk kurulu otomatik seçili (mevcut config değeri kuruluysa o). Bitir.

Seçiciler `@State` yerel tutar; Bitir'de config'e yazılır. Atla her adımda görünür.

### L10n (yeni TR/EN anahtarlar)

`onbWelcomeTitle`, `onbWelcomeBody`, `onbRootsTitle`, `onbRootsBody`, `onbAppsTitle`, `onbNext`, `onbBack`, `onbFinish`, `onbSkip`, `onbRerun`.

---

## Bölüm 3 — Test

- **Core:** `Config.onboardingCompleted` — eksik dosyada `false`; round-trip korunur.
- Wizard view test edilmez (proje kuralı: GUI target testsiz).

## Dosya dokunuş özeti

- `Sources/TwigCore/Models/Config.swift` — `onboardingCompleted`.
- `Sources/TwigCore/L10n/L10n.swift` — onboarding anahtarları TR/EN.
- `Sources/Twig/Views/OnboardingView.swift` — yeni sihirbaz.
- `Sources/Twig/Views/MenuContentView.swift` — overlay tetiği.
- `Sources/Twig/Views/SettingsView.swift` — "Onboarding'i tekrar çalıştır".
- `Tests/TwigCoreTests/ConfigStoreTests.swift` — flag decode/round-trip.
