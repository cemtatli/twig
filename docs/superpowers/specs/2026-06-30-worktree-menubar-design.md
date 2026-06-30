# Worktree Menubar Tool — Tasarım

**Tarih:** 2026-06-30
**Durum:** Onaylandı (uygulama planı bekliyor)

## Amaç

Aynı anda 4+ projede ve aynı projede birden fazla branch'te paralel geliştirme
yapmayı pratikleştirmek. Bugünkü akış — bir branch'te `git stash` alıp diğerine
geçmek — verimsiz. Bunun yerine `git worktree` ile her branch/task için izole bir
çalışma klasörü açan, kurulumunu otomatikleştiren ve macOS menubar'dan tek tıkla
erişilen küçük bir araç.

## Kapsam Dışı (YAGNI)

- Full `git clone` modu (worktree yeterli).
- Notarization / App Store dağıtımı (kişisel araç, yerel çalışır).
- Uzak (remote) branch yönetimi, PR oluşturma vb. — araç sadece yerel worktree
  yaşam döngüsüyle ilgilenir.

## Temel Kararlar

| Konu | Karar |
|------|-------|
| Mekanizma | `git worktree` (paylaşımlı `.git`, hafif, hızlı) |
| Repo keşfi | Klasör tarama (`~/Dev`) **+** manuel eklenen repolar |
| Branch | Var olan branch checkout **veya** yeni branch (base seçilir) |
| Worktree konumu | Şablon: `{group}/task/{type}/{taskName}` |
| Task adı | Branch adından otomatik dolar, düzenlenebilir |
| Kurulum sonrası | Env şablonu (kopyala-ve-satır-değiştir) + kurulum komutları |
| Editör | Cursor |
| Aksiyonlar | Editörde aç, Terminalde aç, Finder'da aç, Sil |
| Teknoloji | SwiftUI + `MenuBarExtra` |
| git erişimi | `git` binary'sine `Process` ile doğrudan çağrı |
| Ayar deposu | İnsan-okunur JSON (`~/.config/worktree-gui/config.json`) |
| Sandbox | Yok (kişisel araç; `~/Dev` ve `git`'e serbest erişim) |

## Mimari

Her katman tek sorumluluğa sahip, ayrı test edilebilir.

```
┌─────────────────────────────────────────────┐
│  UI katmanı (SwiftUI MenuBarExtra)           │
│  - Menü: repo listesi, worktree listesi      │
│  - "Yeni worktree" formu, Ayarlar penceresi  │
├─────────────────────────────────────────────┤
│  Servisler                                    │
│  - RepoScanner   (~/Dev tarar + manuel repo)  │
│  - GitService    (worktree add/list/remove)   │
│  - SetupRunner   (env şablonu + komutlar)     │
│  - Launcher      (Cursor/Terminal/Finder)     │
├─────────────────────────────────────────────┤
│  Model + Ayar deposu                          │
│  - Config (JSON)                              │
│  - Repo, Worktree, RepoSettings tipleri       │
└─────────────────────────────────────────────┘
```

### Birimler ve sorumlulukları

- **RepoScanner** — `scanRoots` altındaki git repolarını `scanDepth`'e kadar
  bulur, `manualRepos`'u ekler, birleşik repo listesi üretir. Gizli klasörleri
  (`.worktrees` vb.) ve worktree klasörlerini atlar.
- **GitService** — `git worktree add/list/remove`, branch listeleme, base repo
  temizlik kontrolü. `Process` çağrıları soyutlanır (testte sahtelenebilir).
- **SetupRunner** — `envRules`'u uygular (base dosyayı kopyala, ilgili `key`
  satırını şablonla değiştir), `setupCommands`'ı worktree klasöründe sırayla
  çalıştırır, ilerleme/log üretir.
- **Launcher** — verilen yolu Cursor / yapılandırılmış terminal / Finder'da açar.
- **Config** — JSON dosyasını okur/yazar, placeholder çözümleme yardımcılarını
  sağlar.

## Veri Modeli (config.json)

```jsonc
{
  "scanRoots": ["~/Dev"],
  "scanDepth": 3,
  "manualRepos": ["~/work/clientZ"],
  "terminalApp": "Terminal",        // veya "iTerm"
  "editorApp": "Cursor",
  "repos": {
    "example_repos/example-admin": {
      "type": "admin",
      "worktreePath": "{group}/task/{type}/{taskName}",
      "defaultBase": "develop",
      "envRules": [
        { "file": ".env.development", "key": "VITE_API_URL",
          "value": "https://{taskName}.dev.example.com/api" }
      ],
      "setupCommands": ["npm install"]
    },
    "example_repos/example-student": {
      "type": "student",
      "envRules": [
        { "file": ".env.development", "key": "VITE_API_URL",
          "value": "https://student-{taskName}.dev.example.com/api" }
      ],
      "setupCommands": ["npm install"]
    }
  },
  "defaults": {
    "worktreePath": "{group}/task/{type}/{taskName}",
    "defaultBase": "main"
  }
}
```

### Placeholder'lar

Yol, env değeri ve komutlarda kullanılabilir:

- `{group}` — base reponun ait olduğu üst grup klasörü (ör. `example_repos`).
- `{repo}` — repo klasör adı (ör. `example-admin`).
- `{type}` — repo ayarındaki proje türü (ör. `admin`); tanımsızsa repo adından
  türetilir.
- `{taskName}` — kullanıcının girdiği task adı (branch'ten otomatik dolar).
- `{branch}` — git branch adı.

### Çözümleme kuralları

- Repo `repos` altında tanımlıysa onun ayarı, değilse `defaults` kullanılır.
- `worktreePath` base reponun bulunduğu konuma göre çözülür; sonuç git'in
  kabul ettiği bir hedef yola dönüştürülür.

## Akış — Yeni Worktree Açma

1. Menüden repo seç → **"+ Yeni Worktree"**.
2. Form:
   - ○ Var olan branch (mevcut branch listesinden) **veya**
   - ○ Yeni branch (ad gir + base branch seç).
   - `taskName` branch adından otomatik dolar, düzenlenebilir.
3. **Oluştur** → sırayla:
   1. Hedef yolu placeholder'larla hesapla.
   2. `git worktree add <yol> <branch>` (yeni branch ise `-b <branch> <base>`).
   3. `envRules`: base repodaki dosyayı worktree'ye kopyala, ilgili `key`
      satırını şablona göre güncelle (diğer satırlara dokunma).
   4. `setupCommands`'ı worktree klasöründe sırayla çalıştır; ilerleme/log
      gösterilir.
4. Bitince worktree menüde görünür.

## Worktree Listesi & Aksiyonlar

- Liste **`git worktree list`** çıktısından okunur — tek doğru kaynak git'tir,
  araç kendi durumunu ayrıca tutmaz.
- Bir worktree'ye tıklayınca:
  - **Cursor'da aç** — `cursor <yol>`.
  - **Terminalde aç** — yapılandırılmış terminalde o klasöre `cd` etmiş halde.
  - **Finder'da aç** — `open <yol>`.
  - **Sil** — `git worktree remove <yol>`; ardından branch'i de silmek için
    onay sorulur.

## Hata Yönetimi

- Her `git`/komut adımı çıkış kodunu ve `stderr`'i yakalar; başarısızsa akış
  durur, hata menüde/log'da gösterilir.
- Yarım kalan worktree için temizlik önerilir (yarım durum bırakılmaz).
- Kontrol edilen durumlar: zaten var olan worktree/yol çakışması, kirli base
  repo, var olmayan branch/base, çözümlenemeyen placeholder.

## Test Stratejisi

Saf birimler izole test edilir; `Process` çağrıları soyutlanarak sahtelenebilir:

- **GitService** — komut argümanlarının doğru kurulması, çıktı ayrıştırma,
  hata yolları.
- **SetupRunner** — placeholder değişimi, env satır güncelleme (sadece hedef
  `key` değişmeli, diğer satırlar korunmalı).
- **RepoScanner** — derinlik sınırı, gizli/worktree klasörlerini atlama,
  manuel repoların birleştirilmesi.
- **Config** — JSON parse/serialize, repo-override vs. defaults çözümlemesi.

## Açık Olmayan / Sonraya Bırakılanlar

- Terminal uygulaması başlangıçta `Terminal`; iTerm desteği ayardan seçilir.
- İlk sürümde tek `scanRoot` (`~/Dev`) yeterli; çoklu kök zaten destekli.
