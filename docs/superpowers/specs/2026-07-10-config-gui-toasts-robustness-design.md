# Config GUI + Toast'lar + Robustness — Tasarım

**Tarih:** 2026-07-10
**Durum:** Onaylandı, implementasyona hazır

## Amaç

Üç özellik, prod'a yaklaşmak için:

1. **Config GUI** — env/setup ve diğer per-repo ayarları JSON elle düzenlemeden GUI'den yönetmek.
2. **Toast'lar** — aksiyonlardan sonra (oluştu/silindi/temizlendi) minik geçici bildirim.
3. **Robustness** — hataları toast'a taşımak, `mergeStatus` maliyetini düşürmek, `refresh` debounce.

## Mevcut durum (keşif)

- `RepoSettings` (Codable): `type?`, `worktreePath?`, `defaultBase?`, `envRules?`, `setupCommands?`, `packageManager?`. Hepsi opsiyonel; resolution repo-değeri else `defaults`.
- `Defaults`: `worktreePath`, `defaultBase`, `envRules?`, `setupCommands?`.
- `EnvRule`: `file`, `key`, `value`.
- Per-repo **paket yöneticisi** şu an Settings pane'inde repo listesinden düzenleniyor (`packageManagerRow`).
- **Toast/overlay/notification altyapısı yok.**
- Hatalar `AppState.lastError` string'ine yazılıp repo detail header'ında kalıcı satır olarak gösteriliyor.
- `refresh()` `Task.detached` içinde **tüm** repolar için worktree listeler; her worktree için `isDirty` + `mergeStatus` (worktree başına ~3 git süreci) hesaplar. Çok repo/worktree'de yavaş.

## Kapsam dışı (YAGNI)

Toast kuyruğu/stack (tek toast yeterli), undo, per-repo ayarların Settings + sheet'te çift gösterimi.

---

## Bölüm 1 — Per-repo Config sheet

### Giriş noktası

Repo detail header'ına ⚙ (`gearshape`) buton, ↻ (refresh) butonundan önce. Tıkla → `.sheet` sunar.

### Yeni view: `Views/RepoConfigSheet.swift`

`RepoConfigSheet(repo: Repo)`. Alanlar tümü `RepoSettings`; boş alan placeholder olarak ilgili default'u gösterir ve kaydederken `nil` yazılır (defaults'a düşsün):

- **Tip** (`type`) — TextField. Placeholder: repo adının ilk `-`'den sonrası (mevcut türetme).
- **Base branch** (`defaultBase`) — TextField. Placeholder: `config.defaults.defaultBase`.
- **Worktree path** (`worktreePath`) — TextField. Placeholder: `config.defaults.worktreePath`. Altında `{group} {repo} {type} {taskName} {branch}` placeholder ipucu.
- **Paket yöneticisi** (`packageManager`) — pill seçici (Yok / npm / Yarn). **Settings listesinden kaldırılır** (tek yer).
- **Env kuralları** (`[EnvRule]`) — düzenlenebilir liste: her satır `file` / `key` / `value` üç alan + sil butonu; altta "+ kural ekle".
- **Setup komutları** (`[String]`) — düzenlenebilir liste: her satır tek TextField + sil; altta "+ komut ekle".

### Kayıt davranışı

Her değişiklikte `config.repos["{group}/{repo}"]` güncellenir + `saveConfig()`. Boş string alanlar `nil`; boş env/setup listeleri `nil`. `saveConfig()` zaten persist + refresh yapıyor.

### Settings pane değişikliği

- Paket-yöneticisi repo listesi (`packageManagerRow` bölümü) **kaldırılır**.
- Yerine **Defaults** kartı: `worktreePath`, `defaultBase`, default env kuralları, default setup komutları — `config.defaults`'a bağlı, tüm repolar için geçerli. Aynı `EditableList` / `KeyValueList` control'lerini kullanır.

### Yeni control'ler (Controls.swift)

- `EditableListSection` — ekle/sil satır listesi (setup komutları).
- `EnvRuleList` — file/key/value üçlü satır listesi.
Keeby stiliyle (mevcut `DarkTextField`, `card` yüzeyi).

---

## Bölüm 2 — Toast'lar

### Model (Core: `Sources/TwigCore/Models/Toast.swift`)

```swift
public enum ToastKind: Equatable { case success, error, info }
public struct Toast: Identifiable, Equatable {
    public let id: UUID
    public let message: String
    public let kind: ToastKind
    public init(id: UUID = UUID(), message: String, kind: ToastKind) { ... }
}
```

### AppState

```swift
@Published var toasts: [Toast] = []
func toast(_ message: String, kind: ToastKind = .success)
```

- Ekler; `.success`/`.info` ~2.5s, `.error` ~4s sonra otomatik siler (Task + `Task.sleep`, MainActor).
- Aynı anda tek toast gösterilir (yeni gelen öncekini değiştirir; liste bir elemanlı tutulur — stack yok).

### View: `Views/ToastOverlay.swift`

- `body`'ye `.overlay(alignment: .bottom)`.
- Kapsül arkaplan, sol ikon (`checkmark.circle.fill` / `exclamationmark.triangle.fill` / `info.circle.fill`), renk kind'a göre (success yeşil, error danger, info accent).
- Solarak + alttan kayarak gelir/gider (`reduceMotion`'da yalnız opacity). Tıkla-kapat.

### Tetikleyenler (AppState aksiyonları)

- Worktree oluştu → "{taskName} oluşturuldu" (`.success`)
- Worktree silindi → "{branch} silindi"
- Worktree+branch silindi → "{branch} (+branch) silindi"
- Zorla silindi → "{branch} zorla silindi"
- Merged temizlendi → "{n} worktree temizlendi"
- Favori eklendi/çıkarıldı → "{repo} favlara eklendi/çıkarıldı" (`.info`)
- Config kaydı: sessiz (toast yok).

---

## Bölüm 3 — Robustness

### 3.1 Hata UX

- `AppState`'teki tüm `lastError = "\(error)"` atamaları → `toast(friendlyMessage(error), kind: .error)`.
- Repo detail header'daki kalıcı `lastError` satırı **kaldırılır**. `lastError` @Published alanı da kaldırılır; hatalar yalnız toast ile gösterilir.
- Kısa mesaj map'i (Core, test edilir): `GitError.command` → stderr'in son boş-olmayan satırı; diğer tipli hatalar → `errorDescription`/`"\(error)"` kısaltması.

### 3.2 mergeStatus maliyeti — lazy per-repo

- `refresh()` artık worktree başına `isDirty` + `mergeStatus` hesaplamaz; yalnız worktree **listesini** ve prune'u yapar (ucuz).
- Ağır per-worktree durum (`isDirty`, `mergeStatus`, `isPrimary`) yalnız **seçili repo** için hesaplanır: repo seçilince ya da o repo refresh edilince ayrı bir `Task.detached` doldurur, `worktreesByRepo[repo.path]`'i günceller.
- Görsel: seçili olmayan repolar worktree listesini rozetsiz/dot'suz gösterir; repo seçilince dolar. "Merged temizle" butonu ve rozetler seçili repo için doğru.

### 3.3 refresh debounce

- Ardışık `refresh()` çağrıları coalesce: son çağrı ~150ms sonra çalışır (önceki bekleyeni iptal eder). Basit `Task` iptali ile.

---

## Test (TwigCoreTests, FakeProcessRunner)

Tüm mantık Core'da test edilir; GUI view'ları test edilmez (proje kuralı).

1. **Toast model** — `Toast`/`ToastKind` Equatable, init default id.
2. **friendlyMessage(error)** — `GitError.command(stderr: "a\nfatal: boom\n")` → "fatal: boom"; boş stderr → makul fallback; non-GitError → tipin açıklaması.
3. **Config round-trip** — `RepoSettings` (env + setup dolu) encode→decode korunur; boş alanlar `nil`.
4. (Lazy/debounce saf mantık Core'a çıkarılırsa test; AppState'te kalırsa kapsam dışı.)

## Dosya dokunuş özeti

- `Sources/TwigCore/Models/Toast.swift` — yeni.
- `Sources/TwigCore/Git/GitService.swift` veya yeni helper — `friendlyMessage` (error→kısa string).
- `Sources/Twig/AppState.swift` — `toasts`/`toast`, lazy per-repo durum hesabı, debounce, hata→toast, aksiyon toast'ları, `packageManager` API korunur.
- `Sources/Twig/Views/RepoConfigSheet.swift` — yeni per-repo config sheet.
- `Sources/Twig/Views/ToastOverlay.swift` — yeni.
- `Sources/Twig/Views/MenuContentView.swift` — ⚙ buton + sheet sunumu, header error satırı kaldır, ToastOverlay ekle.
- `Sources/Twig/Views/SettingsView.swift` — PM listesi kaldır, Defaults kartı ekle.
- `Sources/Twig/Views/Controls.swift` — `EditableListSection`, `EnvRuleList`.
- `Sources/TwigCore/L10n/L10n.swift` — yeni anahtarlar TR/EN.
- `Tests/TwigCoreTests/*` — Toast, friendlyMessage, RepoSettings round-trip.
