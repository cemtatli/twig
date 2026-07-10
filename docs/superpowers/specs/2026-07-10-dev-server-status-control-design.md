# Dev Server Durumu + Kontrol — Tasarım

**Tarih:** 2026-07-10
**Durum:** Onaylandı, implementasyona hazır

## Amaç

Worktree'nin dev server'ı çalışıyor mu göstermek ve tarayıcıda aç / durdur aksiyonları vermek. Terminal akışı korunur (dev server hâlâ harici terminalde `pm.devCommand` ile başlar); Twig process'i sahiplenmez, port üzerinden gözlemler.

## Mevcut durum

- `createWorktree` sonrası `AppState` dev server'ı terminalde açar (`Launcher.openInTerminal` + `pm.devCommand`).
- Twig dev process'ini tutmaz; port/PID bilgisi yok.
- `loadStatus(for:)` seçili repo için `isDirty` + `mergeStatus` hesaplar (lazy). Dev durumu buraya eklenecek.

## Kapsam dışı (YAGNI)

In-app log görüntüleme, otomatik restart, port çakışma çözümü, dev server'ı Twig'in kendisinin (terminal yerine) çalıştırması.

---

## Bölüm 1 — Model & tespit

### Config (`RepoSettings`)

```swift
public var devPort: Int?   // opsiyonel; nil → dev-server özellikleri pasif
```
Resilient decode (mevcut opsiyonel alan kalıbı; RepoSettings zaten tümüyle opsiyonel).

### Model (`Worktree`)

```swift
public var devRunning: Bool = false   // loadStatus doldurur
```

### Tespit stratejisi

Port repo-geneli; hangi worktree çalıştırıyor cwd ile ayrıştırılır:
1. `lsof -nP -iTCP:{port} -sTCP:LISTEN -Fp` → dinleyen PID (`p<pid>` satırı).
2. `lsof -a -p {pid} -d cwd -Fn` → process cwd (`n<path>` satırı).
3. cwd, worktree yolunun altındaysa (`cwd == path || cwd.hasPrefix(path + "/")`) → o worktree çalışıyor.

Port dinlenmiyorsa (PID yok) tüm worktree'ler kapalı.

---

## Bölüm 2 — DevServer Core servisi

Yeni `Sources/TwigCore/Dev/DevServer.swift`, ProcessRunner seam üstünde:

```swift
public struct DevServer {
    public init(runner: ProcessRunner)
    public func listeningPID(port: Int) -> Int?
    public func processCwd(pid: Int) -> String?
    public func isRunning(port: Int, worktreePath: String) -> Bool
    public func stop(port: Int) throws          // PID bul → kill; PID yoksa no-op
}
```

- `listeningPID`: `lsof -nP -iTCP:{port} -sTCP:LISTEN -Fp`; çıktıdan ilk `p` ile başlayan satırın sayısını al. Hata/boş → nil.
- `processCwd`: `lsof -a -p {pid} -d cwd -Fn`; `n` ile başlayan satırın kalanı. Hata/boş → nil.
- `isRunning`: `listeningPID` var **ve** `processCwd` worktreePath ile eşleşiyor (altında).
- `stop`: `listeningPID` varsa `kill {pid}` çalıştır (runner). PID yoksa hiçbir şey yapma. Kill exit≠0 → throw.

Hepsi non-throwing tespit (lsof hatası → nil/false); yalnız `stop` throw eder.

### Launcher

```swift
public func openURL(_ url: String) throws   // open <url>
```
Dev server için `http://localhost:{port}`.

---

## Bölüm 3 — AppState wiring

- `loadStatus(for repo:)`: reponun `devPort`'u varsa, her worktree için `devRunning = DevServer(...).isRunning(port:, worktreePath:)`. Port nil → devRunning false, hesap yok.
- `func openDevServer(repo:worktree:)`: `devPort` varsa `launcher.openURL("http://localhost:\(port)")`.
- `func stopDevServer(repo:worktree:)`: `devPort` varsa `DevServer.stop(port:)`; başarı → `toast(... durduruldu, .info)`; sonra `loadStatus(for: repo)`. Hata → `toast(friendlyMessage, .error)`.
- Port yoksa bu metodlar no-op.

---

## Bölüm 4 — UI

### worktreeRow (`MenuContentView`)

- Reponun `devPort`'u tanımlı **ve** `wt.devRunning` ise: branch yanında yeşil "running" `TagBadge(filled: true)` (nokta/etiket).
- Hover aksiyon ikonlarına (mevcut editor/terminal/finder/trash file'ının yanına):
  - **Tarayıcıda aç** (`globe`) — devPort tanımlıysa görünür.
  - **Durdur** (`stop.circle`, danger) — yalnız `devRunning` iken görünür.

### RepoConfigSheet

- Yeni **Dev port** alanı (paket yöneticisi yakınında): sayısal `DarkTextField`, boş = kapalı. Kayıtta `Int(text)` → `devPort` (geçersiz/boş → nil).

### L10n

Yeni TR/EN anahtarlar: `cfgDevPort`, `devOpenBrowser`, `devStop`, `devRunning`, `toastDevStopped`.

---

## Test (TwigCoreTests, FakeProcessRunner)

1. **listeningPID** — `lsof` stdout `"p1234\nf5\n"` → 1234; boş → nil; doğru args (`-nP -iTCP:3000 -sTCP:LISTEN -Fp`).
2. **processCwd** — `"p1234\nfcwd\nn/Users/x/wt\n"` → "/Users/x/wt"; boş → nil.
3. **isRunning** — cwd worktree altında → true; farklı cwd → false; PID yok → false (FIFO ile lsof çağrılarını sırayla stub'la).
4. **stop** — PID varsa `kill 1234` çağrısı kaydedilir; PID yoksa kill çağrısı yok.
5. **Config round-trip** — `devPort` encode/decode.

## Dosya dokunuş özeti

- `Sources/TwigCore/Models/Config.swift` — `RepoSettings.devPort`.
- `Sources/TwigCore/Models/Repo.swift` — `Worktree.devRunning`.
- `Sources/TwigCore/Dev/DevServer.swift` — yeni servis.
- `Sources/TwigCore/Launch/Launcher.swift` — `openURL`.
- `Sources/TwigCore/L10n/L10n.swift` — yeni anahtarlar.
- `Sources/Twig/AppState.swift` — loadStatus devRunning, open/stop metodları.
- `Sources/Twig/Views/MenuContentView.swift` — running badge + aç/durdur aksiyonları.
- `Sources/Twig/Views/RepoConfigSheet.swift` — Dev port alanı.
- `Tests/TwigCoreTests/*` — DevServer + Config testleri.
