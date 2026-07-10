# Favoriler + Worktree Temizlik (silme/prune) — Tasarım

**Tarih:** 2026-07-10
**Durum:** Onaylandı, implementasyona hazır

## Amaç

Twig'i kişisel araçtan daha geneli kullanılabilir bir araca taşıyan iki özellik:

1. **Repo favorileri** — çok repo olduğunda hızlı erişim için sidebar'da sabitleme.
2. **Worktree temizlik iyileştirmeleri** — mevcut silme akışının gerçek boşluklarını kapatmak: dirty-safe silme, merged durum rozeti, toplu "merged temizle", manuel prune.

## Mevcut durum (keşif bulgusu)

Temel worktree silme **zaten var ve tam bağlı**:
- `worktreeRow` (MenuContentView): hover'da çöp ikonu + sağ-tık menüsü → inline onay.
- İki mod: sadece worktree (`removeWorktree(deleteBranch: false)`) / worktree+branch (`deleteBranch: true`).
- `AppState.removeWorktree(repo:worktree:deleteBranch:)` → `GitService.removeWorktree` + opsiyonel `deleteBranch`.
- `git.prune` `refresh`'te otomatik çalışıyor (klasörü silinmiş stale kayıtları düşer).
- `isDirty` her worktree için `refresh`'te hesaplanıp 6pt renkli nokta ile gösteriliyor.

Boşluklar: (a) `git worktree remove` dirty worktree'de `--force` olmadan patlar → kriptik hata; (b) merge edilmiş worktree'leri toplu temizleme yok; (c) hangi worktree güvenle silinir belirsiz; (d) manuel prune tetiği yok. Favori altyapısı hiç yok.

## Kapsam dışı (YAGNI)

Worktree bazında favori, disk-kullanımı gösterimi, PR/CI durumu, otomatik (onaysız) merged silme.

---

## Bölüm 1 — Config & model

### Config (`Sources/TwigCore/Models/Config.swift`)

Tek yeni alan:

```swift
/// Sidebar'da favori olarak sabitlenen repolar, "{group}/{repo}" anahtarları.
public var favoriteRepos: [String]
```

- `CodingKeys`'e `favoriteRepos` eklenir.
- `init(from:)` resilient decode: eksikse `[]` (`decodeIfPresent ... ?? []`).
- `Config.default` içinde `favoriteRepos: []`.
- `init(...)` imzasına `favoriteRepos: [String] = []` (varsayılanlı, geriye uyumlu).

Anahtar şeması mevcut `repoOrder` / `repos` (RepoSettings) ile birebir aynı: `"{group}/{repo}"`.

### Model (`Sources/TwigCore/Models/Repo.swift`)

`Worktree`'ye senkron durumu:

```swift
public enum SyncStatus: Equatable {
    case merged                    // branch tamamen base'in içinde → güvenle silinir
    case ahead(Int)                // base'in önünde N commit
    case behind(Int)               // base'in gerisinde M commit
    case diverged(ahead: Int, behind: Int)
    case even                      // base ile eşit
    case unknown                   // hesaplanamadı (base ref yok, detached, vs.)
}
```

`Worktree` yeni alanlar (varsayılanlı, geriye uyumlu init):

```swift
public var sync: SyncStatus = .unknown
public var isPrimary: Bool = false   // branch == base olan ana worktree; silinemez/rozetsiz
```

### GitService (`Sources/TwigCore/Git/GitService.swift`)

**Değişen:** `removeWorktree` `force` parametresi alır.

```swift
public func removeWorktree(repoPath: String, worktreePath: String, force: Bool = false) throws {
    var args = ["-C", repoPath, "worktree", "remove", worktreePath]
    if force { args.append("--force") }
    try git(args)
}
```

**Yeni:** merge durumu hesaplama.

```swift
public func mergeStatus(repoPath: String, branch: String, base: String) -> SyncStatus
```

Algoritma:
1. Base ref çöz: `origin/<base>` `hasRef` ile varsa onu, yoksa yerel `<base>`, o da yoksa `.unknown`.
2. Merged mi: `git -C <repo> merge-base --is-ancestor <branch> <resolvedBase>` exit 0 → branch base'in içinde. (branch == base durumunu çağıran taraf primary olarak eler.)
3. ahead/behind: `git -C <repo> rev-list --left-right --count <resolvedBase>...<branch>` → `"<behind>\t<ahead>"`.
   - behind==0 && ahead==0 → `.even` (merged değilse; merged ise adım 2 kazanır).
   - ahead>0 && behind==0 → `.ahead(ahead)`
   - ahead==0 && behind>0 → `.behind(behind)`
   - ikisi de >0 → `.diverged(ahead, behind)`
4. Merged öncelikli: merge-base ancestor ise `.merged` döner (ahead 0 demektir).
5. Herhangi bir git hatası → `.unknown` (silme/rozet akışı bunu güvenli-olmayan sayar, toplu temizlemeye girmez).

`git worktree prune` zaten `prune(repoPath:)` olarak var; değişmez.

---

## Bölüm 2 — Favoriler

### AppState (`Sources/Twig/AppState.swift`)

```swift
func isFavorite(_ repo: Repo) -> Bool          // "{group}/{repo}" config.favoriteRepos'ta mı
func toggleFavorite(_ repo: Repo)              // ekle/çıkar → saveConfig()
var favoriteRepos: [Repo] { ... }              // state.repos'tan, config.favoriteRepos sırasıyla
```

`favoriteRepos`: `config.favoriteRepos` anahtar sırasını korur; artık taranmayan (kaybolmuş) anahtarlar atlanır.

### Sidebar (`Sources/Twig/Views/MenuContentView.swift`)

- `groupedRepos`'un **üstünde** "FAVORİLER" section'ı (`Theme.sectionLabel`).
- Favori repolar bu section'da **tekrar** görünür (kısayol) **ve** grubunda kalır.
- Favori yoksa section hiç render edilmez.
- `repoRowView` yeniden kullanılır. `globalIndex` her iki kopyada da `state.repos`'taki gerçek indeksten gelir → **karo rengi + numara ipucu tutarlı** (aynı repo iki satırda aynı renk).
- Favoriler section satırlarında `moveUp/moveDown` gizli/anlamsız (grup içi sıralama için değil) — bu satırlarda favori-toggle ve Finder yeterli.

### Toggle giriş noktaları

- `repoRowView` context-menu'ye: "⭐ Favlara ekle" / "Favlardan çıkar" (`isFavorite`'e göre etiket) — mevcut moveUp/moveDown/Finder menüsüne eklenir.
- (Cila, opsiyonel) Favoriler section satırında hover'da dolu-yıldız ikon → tek tıkla çıkar.

### L10n (`Sources/TwigCore/L10n/L10n.swift`)

Yeni anahtarlar TR/EN: `.favoritesSection` ("FAVORİLER" / "FAVORITES"), `.addFavorite`, `.removeFavorite`.

---

## Bölüm 3 — Silme/prune iyileştirmeleri

### 3.1 Dirty-safe silme

Mevcut inline onay akışı (`confirmingRemovalPath`) genişletilir:

- Onaylanan worktree `isDirty` ise: satırda ⚠ "Kaydedilmemiş değişiklik var" uyarısı + pill **"Zorla sil"** → `removeWorktree(..., force: true)`.
- Clean worktree'de mevcut davranış aynen korunur (worktree / worktree+branch pill'leri, force yok).
- `AppState.removeWorktree` `force: Bool = false` parametresi kazanır ve `GitService.removeWorktree`'ye iletir.

### 3.2 Merged rozeti

- `refresh` (Task.detached) içinde, `isDirty`'nin yanında her worktree için `mergeStatus` hesaplanır; `Worktree.sync` ve `isPrimary` doldurulur.
- Primary worktree tespiti: `worktrees` listesinde branch == çözülmüş base olan (tipik ilk giriş). Primary → `isPrimary = true`, rozetsiz, silme aksiyonu gizli.
- `worktreeRow`'da branch yanında küçük pill:
  - `.merged` → yeşil "merged"
  - `.ahead(n)` → "↑n"
  - `.behind(m)` → "↓m"
  - `.diverged(a,b)` → "↑a ↓b"
  - `.even` / `.unknown` → rozet yok
- Performans: git çağrıları zaten off-main Task.detached'te; her worktree için +2 hızlı git çağrısı (merge-base, rev-list).

### 3.3 Toplu "Merged temizle" (repo düzeyi)

- Repo detail header'ına buton: **"Merged temizle"**. Yalnız reponun ≥1 `merged` + clean (dirty olmayan, primary olmayan) worktree'si varsa aktif.
- Tıkla → onay paneli: silinecek worktree'leri listeler; dirty merged worktree'ler **atlanır** ve "N tanesi kaydedilmemiş değişiklik nedeniyle atlandı" notu gösterilir.
- Onayla → her biri worktree+branch olarak silinir (`deleteBranch: true`, `force: false` — clean oldukları garanti).
- `AppState.cleanMergedWorktrees(repo:)`; git etkileşimleri `GitService` üzerinden.

### 3.4 Manuel prune butonu

- `repoRowView` context-menu'ye "Stale kayıtları temizle" → `git.prune(repoPath:)` + `refresh()`.
- Auto-prune (refresh'te) korunur; bu açık tetiktir.

### L10n

Yeni anahtarlar TR/EN: `.forceDelete`, `.dirtyWarning`, `.cleanMerged`, `.cleanMergedConfirm`, `.skippedDirtyNote`, `.pruneStale`, badge metinleri (`merged` sabit).

---

## Test (TwigCoreTests, FakeProcessRunner)

Tüm mantık Core'da test edilir; GUI target'ının testi yok (proje kuralı).

1. **`removeWorktree(force:)`** — `force: true`/`false` için kaydedilen `calls.args` doğru (`--force` var/yok).
2. **`mergeStatus` parse** — kuyruğa git çıktısı verilip her SyncStatus üretilir:
   - merge-base ancestor exit 0 → `.merged`
   - rev-list "0\t3" → `.ahead(3)`; "2\t0" → `.behind(2)`; "2\t3" → `.diverged(3,2)`; "0\t0" → `.even`
   - base ref yok / git hatası → `.unknown`
   - base çözümü: `origin/<base>` varsa onu kullandığını `calls` ile doğrula.
3. **Config decode** — `favoriteRepos` alanı olmayan JSON dosyası `[]` ile yüklenir; round-trip encode/decode korur.
4. **Favori mantığı** — `isFavorite`/`toggleFavorite` (Core'a taşınabilir saf yardımcı varsa) veya AppState davranışı; `favoriteRepos` sırası config sırasını korur, kayıp anahtarları atlar.
5. **`cleanMergedWorktrees`** — merged+clean olanlar silinir (doğru `worktree remove` + `branch -D` çağrıları), dirty/primary olanlar atlanır.

## Dosya dokunuş özeti

- `Sources/TwigCore/Models/Config.swift` — `favoriteRepos`.
- `Sources/TwigCore/Models/Repo.swift` — `SyncStatus`, `Worktree.sync`/`isPrimary`.
- `Sources/TwigCore/Git/GitService.swift` — `removeWorktree(force:)`, `mergeStatus`.
- `Sources/TwigCore/L10n/L10n.swift` — yeni anahtarlar TR/EN.
- `Sources/Twig/AppState.swift` — favori API, `removeWorktree(force:)`, `cleanMergedWorktrees`, refresh'te mergeStatus.
- `Sources/Twig/Views/MenuContentView.swift` — Favoriler section, favori toggle menü, dirty-safe onay, merged rozeti, "Merged temizle" butonu, manuel prune menü.
- `Tests/TwigCoreTests/*` — yukarıdaki testler.
