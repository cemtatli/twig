# Jig — HIG denetimi düzeltmeleri

Date: 2026-07-02
Status: approved (design)
Builds on: `2026-06-30-native-consistency-restyle-design.md` (uygulanmış).

## Context

Native-consistency restyle uygulandıktan sonra tam bir HIG + ui-ux-pro-max
denetimi yapıldı: üç görünüm (sidebar/detail, New Worktree, Settings) kod
düzeyinde tarandı ve app derlenip Light/Dark ekran görüntüleriyle doğrulandı.
Commit edilmemiş drag-to-reorder işi (custom sidebar satırları) korunuyor —
kullanıcı kararı: reorder kalır, satır stili native source-list görünümüne
birebir uydurulur.

Davranış değişikliği yok; yalnız görsel/etkileşim düzeltmeleri. `WorktreeCore`
dokunulmaz (repoOrder/moveRepo zaten uncommitted diff'te var ve kalır).

## Bulgular ve düzeltmeler

### A. Ekran görüntüsü bulguları (görsel hatalar)

1. **Detail arka planı yok → popover aşırı şeffaf.** Arkadaki pencere içeriği
   hayalet gibi sızıyor; Light modda sidebar açık renk kalırken detail koyu
   görünüyor ve metin beyaz kalıyor (Light/Dark tutarsızlığı — en kritik bulgu).
   Düzeltme: detail tarafına opak semantik zemin
   `Color(nsColor: .windowBackgroundColor)`; sidebar'a source-list hissi için
   `.background(.ultraThinMaterial)` (altında aynı semantik zemin, böylece
   Light'ta açık/Dark'ta koyu garanti). Mevcut `Divider` ayrımı kalır.
   Uygulamada Light+Dark ekran görüntüsüyle doğrulanacak; ölçüt: iki modda da
   arkadan içerik sızmaması ve metinlerin doğru semantik renkte olması.
2. **Drag grip'leri sürekli görünür.** Native listelerde grip yok; görsel
   gürültü. Düzeltme: grip yalnız satır hover'ında görünür (opacity, 0.12-0.15s,
   Reduce-Motion'da animasyonsuz). Grip alanı sabit kalır (layout kaymaz —
   ui-ux-pro-max "stable interaction states").
3. **Grup başlığı çok silik.** `example_repos` başlığı kaybolgun. Düzeltme: native
   source-list section-header stili — `.caption` → kalınlık `.semibold`,
   `.secondary`, üstte 10pt / altta 4pt boşluk.

### B. Kod denetimi bulguları (HIG + ui-ux-pro-max)

4. **Sidebar seçim rengi.** `Color.accentColor` + sabit `.white` yerine
   `Color(nsColor: .selectedContentBackgroundColor)` zemin + `.white` metin
   (native token; pencere pasifken sistem gri verir). Hover zemini kalır.
5. **Slide-offset animasyonu.** `MenuContentView` worktree satır aksiyonlarındaki
   `offset(x:)` kayması kaldırılır; yalnız opacity reveal kalır (onaylı önceki
   spec'in gereği; Reduce-Motion zaten uyumlu).
6. **Hata metni tipografisi.** Repo detail'deki `lastError` mono+`Theme.danger`
   yerine SF Pro `.caption` + `exclamationmark.triangle` ikonu + system red.
   (Mono kuralı: yalnız path/log. NewWorktree'deki log-altı hata stderr çıktısı
   olduğu için mono kalır.)
7. **Çifte soluklaştırma.** NewWorktree Create butonundaki manuel
   `.opacity(0.4)` kaldırılır; native `.disabled` yeter.
8. **Renk-tek-başına anlamı.** Clean/dirty noktasına satır `.help` tooltip'i
   ("temiz" / "kaydedilmemiş değişiklik var" — mevcut i18n mekanizmasıyla) ve
   `accessibilityLabel` eklenir.
9. **Klavye kısayolları.** Eklenir: ⌘N (Yeni worktree — repo pane'de), ⌘R
   (yenile), ⌘, (Ayarlar), ⌘Q (çık; LSUIElement'te menü yok, kısayol şart),
   Esc (New Worktree pane'ini kapat — form focus'tayken de çalışmalı).
   Mevcut 1-9 / ok / Tab davranışı korunur.
10. **Reorder klavye alternatifi.** HIG: drag-and-drop'a görünür alternatif.
    Repo satırına context menu: "Yukarı taşı" / "Aşağı taşı"
    (`state.moveRepo` mevcut API'siyle; grup sınırında ilgili öğe disabled).
11. **Repo satırı context menu tutarlılığı.** 10'daki menüye ek olarak
    "Editörde aç" / "Terminalde aç" / "Finder'da göster" değil — repo kökü için
    yalnız taşıma + "Finder'da göster" yeterli (worktree aksiyonları worktree
    satırının işi; şişirme yok, YAGNI).
12. **configHint yerleşimi.** Settings'te Form dışındaki config-yolu bloğu son
    `Section`'ın `footer`'ına taşınır (tek "section" deseni korunur).

### Kullanıcı kararları

- **Silme onayı:** satır-içi pill onayı kalır (değişiklik yok).
- **Quit:** `power` ikonu kalır; ⌘Q eklenir (madde 9'un parçası).
- **Drag-to-reorder:** kalır; yalnız stil düzeltmeleri (2, 4) uygulanır.

## Dosya bazında kapsam

- `MenuContentView.swift` — 1, 2, 3, 4, 5, 6, 8, 9, 10, 11 (en büyük parça).
- `NewWorktreeView.swift` — 7, 9 (Esc).
- `SettingsView.swift` — 12.
- `Theme.swift` — muhtemelen değişmez (yeni token gerekmiyor; semantik NSColor
  köprüleri görünüm içinde kalabilir; ortaklaşırsa Theme'e alınır).
- `AppState.swift` / `Config.swift` — yalnız uncommitted reorder diff'i olduğu
  gibi kalır; bu spec yeni state eklemez.

## Scope dışı

- Davranış/mantık değişikliği yok; `WorktreeCore` dokunulmaz.
- Pencere boyutu (540×500 uncommitted değeri) kalır; görsel doğrulamada
  sıkışıklık çıkarsa ayrı konuşulur.
- VoiceOver tam geçişi (rotor, custom actions) bu kapsamda değil; yalnız 8 ve
  10'daki etiket/alternatifler.

## Doğrulama

- `swift build` temiz; `swift test` (Core) yeşil kalır.
- `./scripts/build-app.sh` + popover ekran görüntüsü: Dark ve Light modda
  repo pane; madde 1'in ölçütü (sızıntı yok, semantik renkler doğru) iki modda
  da sağlanmalı. Settings/New pane'leri sentetik tıklamayla açılamıyor
  (popover kapanıyor) — kod tutarlılığı + kullanıcı gözüyle doğrulanır.
- Klavye kısayolları elle: popover açıkken ⌘N/⌘R/⌘,/Esc/⌘Q.
