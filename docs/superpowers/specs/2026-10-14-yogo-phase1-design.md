# Yogo, Faz 1: Tasarım

- **Tarih:** 2026-10-14
- **Durum:** Kullanıcı onayı bekleniyor
- **Cihaz:** ATK YOGO 75 PRO (USB `373B:119B`), ekran 6×6 RGB nokta matris

## 1. Amaç

ATK YOGO 75 PRO klavyesinin 6×6 LED ekranını macOS'tan kontrol eden, Claude Code'un o anki durumunu bu ekranda gösteren ve kullanıcının kendi piksel animasyonlarını çizip oynatabildiği bir menü çubuğu uygulaması.

**Kullanıcının istedikleri:**
- macOS'ta çalışan, bu klavyeye özel bir uygulama.
- Claude **Code** (terminal) çalışırken ekranda Claude temalı bir animasyon görünmesi.
- Kendi görsellerini ekrana koyabilmek. Ekranın 36 piksel olduğu öğrenildikten sonra bu istek "piksel editörü" olarak netleşti.
- RGB ışık ayarları. Bu istek Faz 2'ye ertelendi, gerekçesi §2'de.

**Kullanıcının verdiği kararlar:**
- Maskot olarak **Claude kıvılcımı** (C) seçildi.
- Claude boştayken ekranda **klavyenin kendi efekti** görünecek.
- "Araç çalıştırıyor" animasyonu yavaşlatılacak (her kare yaklaşık 260 ms).
- Arayüz yerleşimi ve "Ekrana sabitle" mantığı onaylandı.

**Başarı ölçütleri:**
1. Claude Code terminalde çalışırken ekran, hook olayından sonra en geç ~300 ms içinde doğru durumun animasyonuna geçer.
2. Birden fazla Claude Code oturumu açıkken en acil durum gösterilir.
3. Hiçbir oturum çalışmıyorsa ekran klavyenin kendi efektine (ya da sabitlenmiş animasyona) döner.
4. Editörde çizilen bir animasyon klavyede canlı önizlenebilir, bir Claude durumuna atanabilir ve ekrana sabitlenebilir.
5. Kablo çıkarılıp takıldığında ya da Mac uyuyup uyandığında uygulama yeniden başlatmaya gerek kalmadan toparlanır.
6. Uygulama hiçbir koşulda Claude Code'u yavaşlatmaz ya da engellemez. Yasaklı bir komut hiçbir zaman cihaza gitmez.

## 2. Kapsam

**Faz 1'e dahil:**
- Menü çubuğu uygulaması
- Claude durum takibi ve hook kurulumu
- Canlı ekran sürücüsü
- Piksel editörü (PNG/GIF içe aktarma dahil)
- Ekrana sabitleme
- Hazır kıvılcım animasyon seti

**Faz 2'ye ertelenenler (ayrı spike ve ayrı spec):**
- **RGB ışık ayarları.** macOS'ta doğrulanmış bir protokol kaynağı yok. Tek ipucu Windows'a özel YogoDot projesinin 33 baytlık komutları.
- **"Klavyeye kaydet" (Flash'a yazma).** Böylece Bluetooth'ta da özel animasyon görünebilir. Komut `0x3B` ve dinamik görsel komutları henüz doğrulanmadı.
- **2.4G dongle desteği** (`373B:11FF`, 24 baytlık paketler). Doğrulanmadı.

**Kapsam dışı:**
- Claude masaüstü uygulamasını izlemek.
- Işıkların Claude'a tepki vermesi.
- Firmware yükleme ya da yamalama, VIA firmware'i.
- Bluetooth üzerinden canlı kontrol. Firmware'de ayar kanalı yok, eklemek için firmware yaması gerekiyor.

## 3. Donanım ve protokol

**Kaynaklar:**
- [Owlbay/atk-yogo75pro-mac-fn](https://github.com/Owlbay/atk-yogo75pro-mac-fn), `docs/点阵屏实时控制分析.md`
- 2026-10-14 tarihli spike. Bu makinede, stok firmware'de, Swift ve IOKit ile çalıştırıldı.
  - Kullanıcı sonucu gözle doğruladı: tam kırmızı ekran ve köşe yönleri doğru.
  - Giriş İzleme izni **gerekmedi**.

### Arayüz

| Özellik | Değer |
|---|---|
| Vendor ID / Product ID | `0x373B` / `0x119B` |
| Usage page / usage | `0xFF60` / `0x61` (yalnızca bu arayüz açılır) |
| Rapor | 64 bayt output report, report ID 0 (`IOHIDDeviceSetReport`) |

- `0xFF00` arayüzü firmware güncelleme kanalıdır. **Bu arayüz asla açılmaz.**
- Bluetooth'ta klavye `36B0:3004` olarak görünür ve ayar kanalı yoktur. Bu ID'ler Owlbay'den alındı, bu makinede henüz doğrulanmadı.

### Paket formatı

Başlık: `AA <cmd> <offset_lo> <offset_hi> <len> <seq_lo> <seq_hi> 00`, veri 8. bayttan başlar.

### Komutlar

| Komut | Anlamı | Faz 1 |
|---|---|---|
| `0x10` | Oturum başlat. Firmware 5 sn sessizlikte oturumu kapatır. | ✅ |
| `0x3C` | Canlı kare. RGB565 little-endian, 36 px = 72 bayt, iki pakette gönderilir: offset 0'da 56 bayt, offset 56'da 16 bayt. | ✅ |
| `0x3D` | Canlı modu bitir, klavyenin efektine dön. | ✅ |
| `0x11` | Oturumu bitir. | ✅ |
| `0x3B` | Sabit görsel, büyük ihtimalle Flash'a yazar. | ❌ yasak (Faz 2'de doğrulanacak) |
| `0x31` | Fabrika ayarı (YogoDot'a göre). | ❌ yasak |
| diğer hepsi | | ❌ yasak |

### Zamanlama

- Canlı modda 0,5 sn boyunca yeni kare gelmezse firmware kendi efektine döner.
- Oturum her 2 saniyede bir `0x10` ile yenilenir. Owlbay da böyle yapıyor. Firmware'in sınırı 5 saniye.

### Piksel sırası

Satır öncelikli, sol üstten başlar: 0 = sol üst, 5 = sağ üst, 30 = sol alt, 35 = sağ alt. Spike'ta doğrulandı.

### Yanıtlar

- Spike'ta cihaz her komuta `AA <cmd> <offset> <len> 00 <seq> 55 …` biçiminde yanıt verdi.
- Kare komutlarının yanıtı beklenmez (gönder ve unut). Yanıtlar okunur ve günlüğe yazılır.
- 3. baytı `0xFF` olan yanıt reddedilmiş demektir. Reddedilen yanıtlar uyarı olarak günlüğe yazılır.

## 4. Mimari

```
Claude Code ──hook (async)──▶ yogo hook ──JSON satırı──▶ SignalServer (Unix socket)
                                                            │
                                                            ▼
Editör (önizleme) ──┐                                ClaudeTracker
Sabitlenmiş anim ───┼──▶ SceneSelector ◀──────────── (birleşik ClaudeState)
Atamalar ───────────┘          │
                               ▼
                       Player (sahne + zaman → Frame)
                               │
                               ▼
                 ScreenDriver (20 Hz döngü, oturum yenileme)
                               │
                               ▼
              ScreenDevice protokolü ─▶ HIDScreenDevice (IOKit) │ FakeScreenDevice (test)
```

### `YogoCore` (kütüphane)

UI ve IOKit içermez. Saat (`now`) dışarıdan verilir, böylece her şey test edilebilir.

| Birim | Görevi | Arayüz |
|---|---|---|
| `Command` | Yalnızca izinli komutlar | `enum Command: UInt8 { startSession = 0x10, liveFrame = 0x3C, endLive = 0x3D, endSession = 0x11 }`. Yasaklı komutlar bu türle **ifade bile edilemez**. |
| `Packet` | 64 baytlık rapor üretir | `Packet.encode(_ cmd: Command, offset: UInt16, data: [UInt8], seq: UInt16) -> [UInt8]` |
| `Frame` | 36 RGB piksel | `struct Frame { var pixels: [RGB] }`, `func liveReports() -> [[UInt8]]` (iki rapor) |
| `Animation` | Kareler ve süreler | `struct Animation: Codable { id, name, loop, frames: [AnimationFrame] }` |
| `AnimationStore` | Hazır ve kullanıcı animasyonlarını okur/yazar | `all()`, `get(id)`, `save(_:)`, `delete(id)` |
| `ClaudeTracker` | Oturum bazlı durum makinesi (§5) | `apply(_ e: HookEvent, at: Date)`, `state(at: Date) -> ClaudeState` |
| `SceneSelector` | Ekranda ne gösterileceğine karar verir (§6) | `select(inputs, at:) -> Scene` (`.play(Animation, since: Date)` veya `.release`) |
| `Player` | Sahne ve zamandan o anki kareyi hesaplar | `frame(for: Scene, at: Date) -> Frame?` |
| `ScreenDriver` | Cihazla konuşan döngü | `tick(at: Date)`, `ScreenDevice` alır |
| `HooksInstaller` | `settings.json` birleştirme, saf fonksiyon | `install(into: Data, cliPath:) throws -> Data`, `uninstall(from:)`, `isInstalled(_:)` |
| `SignalMessage` | Socket mesaj formatı | JSON satırı: `{"event","session","notificationType"?,"tool"?}` |

### `ScreenDriver` davranışı

- `.play` sahnesine geçince önce `0x10` gönderir. Sonra her tick'te o anki kareyi iki rapor halinde yollar ve her 2 saniyede bir `0x10`'u yeniler.
- `.release` sahnesine geçince bir kez `0x3D` ve `0x11` gönderir, sonra hiçbir şey göndermez.
- Tick sıklığı 20 Hz. Kare süreleri bu yüzden 50 ms'nin katlarına yuvarlanır.

### `HIDScreenDevice` (uygulama hedefinde, IOKit)

- `IOHIDManager` yalnızca `373B:119B` + `0xFF60/0x61` ile eşleştirilir.
- Cihaz takılıp çıkarıldığında (hot-plug) callback'lerle haber verir.
- `send` başarısız olursa bir kez tekrar dener. Art arda 5 hata olursa bağlantıyı kapatıp yeniden açar.
- Bluetooth tespiti: `36B0:3004` cihazı yalnızca **listelenir** (açılmaz). Bu cihaz varsa ve kablolu arayüz yoksa durum "Bluetooth" olarak gösterilir. Bu, implementasyon sırasında doğrulanacak.

### `SignalServer`

- Socket yolu `~/Library/Application Support/Yogo/yogo.sock`, izinleri `0600`.
- JSON satırlarını okuyup `ClaudeTracker`'a verir.
- `yogo status` için durum sorgusuna da yanıt verir.

### `yogo` CLI

`Yogo.app/Contents/MacOS/yogo` konumunda durur.

- **`yogo hook`**
  - Claude Code hook JSON'unu stdin'den okur. Kullandığı alanlar: `hook_event_name`, `session_id`, `notification_type`, `tool_name`.
  - Bu alanları socket'e gönderir. Toplam süre en fazla 300 ms.
  - **Her zaman exit 0 ile çıkar ve stdout'a hiçbir şey yazmaz.** Bu yüzden `PermissionRequest` kararlarına asla karışmaz.
- **`yogo simulate <thinking|tool|waiting|done|idle> [--session ID]`:** test ve hata ayıklama için.
- **`yogo status`:** bağlantı durumunu, birleşik Claude durumunu ve oturum sayısını yazar.

### `Yogo.app` (SwiftUI)

- `MenuBarExtra` (menü) ve editör penceresi.
- Ayarlar `UserDefaults` içinde tutulur:
  - `claudeModeEnabled`
  - `pinnedAnimationID?`
  - `staleTimeoutMinutes` (varsayılan 10)
  - `stateAssignments`: durum → animasyon id
- Oturum açılışında otomatik başlatma `SMAppService.mainApp` ile yapılır.

## 5. Claude durum makinesi

**Durumlar:** `idle`, `thinking`, `tool`, `waiting`, `done`

### Olay eşlemesi (oturum bazında, `session_id`)

| Hook olayı | Yeni oturum durumu |
|---|---|
| `SessionStart` | oturum kaydı yoksa `idle` olarak oluşturulur. Varsa durum **değişmez**, çünkü otomatik sıkıştırma (`source=compact`) iş ortasında da tetikleniyor. |
| `UserPromptSubmit` | `thinking` |
| `PreToolUse` | `tool` |
| `PostToolUse`, `PostToolUseFailure` | `thinking` |
| `PermissionRequest` | `waiting` |
| `Notification` + `notification_type` ∈ {`permission_prompt`, `elicitation_dialog`, `agent_needs_input`} | `waiting` |
| `Notification` + `idle_prompt` | `idle` |
| `Stop` | `done` (`doneAt = now`) |
| `StopFailure` | `idle` |
| `SessionEnd` | oturum kaydı silinir |
| diğer olaylar ve `Notification` türleri | yok sayılır, ama oturumun `lastEventAt` zamanı güncellenir |

### Kurallar

- **"Onay bekliyor"un temizlenmesi:** onay verildiğinde ayrı bir olay gelmiyor. Bunun yerine ardından gelen `PreToolUse`, `PostToolUse`, `UserPromptSubmit` ya da `Stop` durumu zaten değiştirir.
- **`done` süresi:** `done` durumu `doneAt`'ten 4 sn sonra `idle` olur.
- **Takılı kalan oturum:** `thinking`, `tool` ya da `waiting` durumundaki bir oturumdan `staleTimeout` süresi boyunca (varsayılan 10 dk) hiç olay gelmezse oturum `idle` sayılır. Bu, Esc ile kesilen işleri temizler, çünkü o durumda `Stop` gelmiyor.
- **Alt ajanlar:** alt ajan olayları aynı `session_id` ile gelir ve ana oturumun parçası sayılır.
- **Birleştirme:** tüm oturumlar arasında en yüksek öncelikli durum seçilir. Sıra: `waiting` > `tool` > `thinking` > `done` > `idle`. Hiç oturum yoksa sonuç `idle`.
- **Claude modu kapalıysa** tracker çalışmaya devam eder, ama `SceneSelector` sonucunu yok sayar.
- **Uygulama sonradan açılırsa** zaten çalışan oturumlar bilinmez, ilk olaylarıyla kendiliğinden tanınırlar.

## 6. Sahne seçimi

Aşağıdaki kurallardan ilk uyan seçilir:

1. Editör açık **ve** "Klavyede canlı önizle" açıksa → editördeki animasyon (döngüde).
2. Claude modu açık **ve** birleşik durum `idle` değilse → o duruma atanmış animasyon.
   - `done` animasyonu döngüsüzdür: bir kez oynar, kalan sürede son karede durur.
   - Durum değişince yeni animasyon baştan başlar. Durum aynı kaldığı sürece animasyon kesilmez.
3. Sabitlenmiş bir animasyon varsa → o animasyon (döngüde).
4. Hiçbiri değilse → `.release`, yani klavyenin kendi efekti.

## 7. Animasyonlar

### Dosya formatı

`~/Library/Application Support/Yogo/Animations/<id>.json`

```json
{
  "version": 1,
  "id": "tool-default",
  "name": "Araç çalıştırıyor",
  "loop": true,
  "frames": [
    { "durationMs": 260, "pixels": ["000000", "e2794f", "…toplam 36 adet hex RGB…"] }
  ]
}
```

### Sınırlar

- Kare sayısı 1–20 arası. 20 sınırı, Faz 2'de klavyeye kaydetmeye uyumlu kalmak için konuldu (hub'daki 720 px sınırı = 20 kare).
- `durationMs` 50–5000 arası.
- Dosya bozuksa atlanır ve günlüğe yazılır.

### Hazır animasyonlar

- Uygulama paketinin içinde, salt okunur.
- Hazır bir animasyon düzenlenirse kopyası oluşturulur ve o durumun ataması kopyaya taşınır.

### Renkler

| Kod | Renk | Hex |
|---|---|---|
| `O` | turuncu | `e2794f` |
| `o` | koyu turuncu | `7a3f2a` |
| `W` | açık | `ffd9c4` |
| `G` | yeşil | `4fd27a` |
| `g` | koyu yeşil | `2a6b3f` |
| `.` | kapalı | `000000` |

### Şekiller (6 satır, yukarıdan aşağı)

```
dot    ......  ......  ..OO..  ..OO..  ......  ......
cross  ......  ..OO..  .OOOO.  .OOOO.  ..OO..  ......
plus   ..OO..  ..OO..  OOOOOO  OOOOOO  ..OO..  ..OO..
xray   O....O  .O..O.  ..OO..  ..OO..  .O..O.  O....O
spark  O.OO.O  .OOOO.  OOOOOO  OOOOOO  .OOOO.  O.OO.O
ring   .OOOO.  O....O  O....O  O....O  O....O  .OOOO.
```

`sparkW` ve `sparkD`, spark şeklinin `W` ve `o` renkleriyle çizilmiş halleri. `ringG` ve `ringg` ise ring şeklinin `G` ve `g` renkleriyle çizilmiş halleri. `off` tamamen kapalı kare.

### Hazır set (kare: süre ms)

| Durum | Döngü | Kareler |
|---|---|---|
| `thinking` | evet | dot 160 · cross 160 · plus 160 · spark 260 · plus 160 · cross 160 · dot 160 · off 120 |
| `tool` | evet | plus 260 · xray 260 |
| `waiting` | evet | sparkW 140 · off 110 · sparkW 140 · off 110 · sparkD 700 |
| `done` | hayır | dot 90 · cross 90 · spark 140 · ringG 520 · ringg 220 · off 900 |

## 8. PNG/GIF içe aktarma

1. Dosya ImageIO ile okunur. GIF'in kareleri ve gecikme süreleri alınır.
2. Her kare ortadan kare olarak kırpılır.
3. CoreGraphics'in yüksek kaliteli küçültmesiyle 6×6'ya indirilir.
4. 20'den fazla kare varsa eşit aralıklarla 20 kare seçilir. Süreler 50–5000 ms aralığına sıkıştırılır.
5. Sonuç editörde yeni bir animasyon olarak açılır. İçe aktarma bir başlangıç noktasıdır, kullanıcı üzerine çizebilir.

## 9. Arayüz (onaylanan taslak)

**Menü:**
1. Başlık ve bağlantı rozeti: "USB bağlı", "Bluetooth · canlı mod kapalı" ya da "Bağlı değil".
2. Claude durumu ve oturum sayısı.
3. Claude modu açma/kapama.
4. "Boştayken" seçimi: klavyenin kendi efekti ya da sabitlenmiş animasyon.
5. Editörü aç (⌘E).
6. Claude Code hook'ları: kur / kaldır, yanında durum.
7. Oturum açılışında başlat.
8. Çıkış.

**Editör:**
- **Sol:** Claude durumları ve kullanıcının animasyonları. Yeni animasyon oluşturma, PNG/GIF içe aktarma.
- **Orta:** 6×6 tuval. Araçlar: kalem, silgi, doldur, geri al / ileri al.
- **Sağ:** palet (§7'deki renkler, kırmızı, mavi, sarı, beyaz) ve özel renk seçici.
- **Alt:** kare şeridi. Kare süresi, kare ekle/çoğalt/sil, oynat, "Klavyede canlı önizle", "Duruma ata" ve "📌 Ekrana sabitle".

## 10. Hook kurulumu

- **Nereye:** `~/.claude/settings.json` dosyasındaki `hooks` bölümüne.
- **Hangi olaylar:** `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `Notification`, `Stop`, `StopFailure`, `SessionEnd`.
- **Her olaya eklenen girdi:**

```json
{ "hooks": [ { "type": "command", "command": "'/Users/<kullanıcı>/Applications/Yogo.app/Contents/MacOS/yogo' hook", "async": true, "timeout": 5 } ] }
```

  `matcher` kullanılmaz, yani girdi o olayın her tetiklenişinde çalışır.

**Kurallar:**
- Bizim girdilerimiz, komut metninde `/Yogo.app/Contents/MacOS/yogo hook` geçmesinden tanınır. Kurulum idempotenttir, kaldırma yalnızca bu girdileri siler.
- Kurulumdan önce `settings.json.yogo-backup-YYYYMMDD-HHMMSS` adıyla yedek alınır.
- Dosya geçerli bir JSON değilse **dokunulmaz** ve kullanıcıya hata gösterilir.
- Diğer tüm anahtarlar ve kullanıcının kendi hook'ları olduğu gibi korunur.
- Kullanıcı, eklenecek olayların listesini bir onay penceresinde görür ve onaylamadan hiçbir şey yazılmaz.
- Zaten açık olan Claude Code oturumları yeni hook'ları ancak yeniden başlatıldıklarında yükler. Bu, onay penceresinde belirtilir.
- `async` ve `timeout` alanlarının şeması, implementasyon sırasında güncel resmi dokümana göre ([hooks](https://code.claude.com/docs/en/hooks)) son kez doğrulanır.

## 11. Hata durumları

| Durum | Davranış |
|---|---|
| Kablo çıkarıldı | Hot-plug callback'i gelir, döngü durur, rozet "Bağlı değil" olur. Kablo takılınca otomatik yeniden bağlanır ve o anki sahne kaldığı yerden devam eder. |
| Mac uykuya geçiyor | `NSWorkspace.willSleep` geldiğinde `.release` gönderilir ve cihaz kapatılır. `didWake` geldiğinde yeniden açılır. |
| Uygulama çöktü | Firmware 0,5 sn içinde kendi efektine döner, ekstra bir şey yapmaya gerek yok. Normal çıkışta `0x3D` ve `0x11` gönderilir. |
| Cihaz açılamadı (meşgul, örneğin ATK HUB açık) | Rozet "Başka bir program klavyeyi kullanıyor" olur. 5 sn arayla yeniden denenir. |
| Cihaz paketi reddetti (`0xFF`) | Uyarı günlüğe yazılır. 5 ret üst üste gelirse canlı mod 30 sn duraklatılır. |
| Socket'e bağlanılamadı (CLI tarafı) | Sessizce exit 0. |
| `settings.json` bozuk | Dosyaya dokunulmaz, kullanıcıya açıklayıcı bir hata gösterilir. |
| Animasyon dosyası bozuk | Dosya atlanır. Atandığı durum hazır animasyona döner. |

**Günlük:** `~/Library/Logs/Yogo/yogo.log`, dönüşümlü tutulur (en fazla 1 MB × 3 dosya).

## 12. Test stratejisi

- **Birim testleri** (`swift test`, `YogoCoreTests`):
  - **`Packet` ve `Frame`:** spike'ta çalıştığı görülen baytlarla birebir karşılaştırma. Örnek: tam kırmızı karenin ilk raporu `aa 3c 00 00 38 00 00 00 00 f8 …`.
  - **`Command`:** izinli komutların ham değerleri tam olarak `{0x10, 0x3C, 0x3D, 0x11}`. `0x3B` ve `0x31` hiçbir yoldan üretilemiyor.
  - **`ClaudeTracker`:** olay dizileri, `done` → `idle` (4 sn), takılı oturum zaman aşımı, çoklu oturum önceliği, `SessionEnd`. Saat sahte olarak dışarıdan verilir.
  - **`SceneSelector` ve `Player`:** öncelik sırası, döngü, `done`'ın son karede kalması, 50 ms yuvarlama.
  - **`ScreenDriver`:** sahte cihazla; `0x10` yenileme sıklığı ve `.release`'te `0x3D` + `0x11`'in yalnızca bir kez gönderilmesi.
  - **`HooksInstaller`:** boş dosya, mevcut hook'lar, idempotent kurulum, kaldırma, bozuk JSON.
  - **`Animation`:** JSON okuma/yazma ve sınır kontrolleri.
- **Entegrasyon testi:** gerçek socket → `SignalServer` → `ClaudeTracker`, sahte bir cihazla. `yogo hook`'a örnek hook JSON'u verilir.
- **Gerçek klavyede kontrol listesi** (kullanıcıyla birlikte):
  1. Hazır animasyonların hepsi `yogo simulate` ile oynatılır.
  2. Kablo çıkarılıp takılır.
  3. Uyku ve uyanma denenir.
  4. Bluetooth'a geçince rozetin doğru göründüğü kontrol edilir.
  5. Editörde canlı önizleme ve sabitleme denenir.
  6. Gerçek bir Claude Code oturumunda olaylar uçtan uca izlenir: prompt → araç → izin → bitti → Esc.

## 13. Proje yapısı ve derleme

```
yogo/
  Package.swift                 # macOS 14+, Swift 6
  Sources/YogoCore/             # §4 kütüphane (UI/IOKit yok)
  Sources/YogoApp/              # SwiftUI menü + editör, HIDScreenDevice, SignalServer
  Sources/yogo/                 # CLI
  Sources/YogoCore/Resources/Animations/*.json  # hazır set (Bundle.module; testler de doğrular)
  Tests/YogoCoreTests/
  scripts/build-app.sh          # release derler, Yogo.app'i oluşturur, ad-hoc imzalar, ~/Applications'a kurar
  docs/superpowers/specs/
```

- `Info.plist` içinde: `LSUIElement = YES` (Dock'ta görünmez), `CFBundleIdentifier = com.barisgcynr.yogo`.
- `yogo` CLI, `Contents/MacOS/` klasörüne kopyalanır.
- Xcode projesi yoktur. Her şey `swift build` / `swift test` ve derleme betiğiyle yapılır.

## 14. Riskler ve açık noktalar

- **Firmware güncellemesi protokolü değiştirebilir.** Reddedilen paketler günlüğe yazılır ve uygulama canlı modu duraklatarak zararsız şekilde geriler.
- **`idle_prompt` zamanlaması ve Esc davranışı resmi dokümanda net değil.** Takılı oturum zaman aşımı bunu güvenceye alıyor. Kontrol listesinin 6. adımında doğrulanacak.
- **Bluetooth ID'leri (`36B0:3004`) bu makinede doğrulanmadı.** Yanlış çıkarsa rozet "Bağlı değil" gösterir ve işlevsellik etkilenmez.
- **LED renkleri ekrandakinden farklı görünür.** Bunu editördeki canlı önizleme çözüyor, renk düzeltmesi YAGNI.

## 15. Faz 2 için notlar

- **RGB:** önce bir spike yapılacak. Kaynaklar:
  - Yerel olarak indirilmiş hub kodu (`EVISION_V2` denetleyicisi).
  - YogoDot'taki 21 (ayar yaz) ve 46 (tek tuş LED) komutları.
  - Owlbay'in salt okunur 0x12/0x14 komutları.
  
  Bu spike'tan sonra ayrı bir spec yazılacak.
- **Klavyeye kaydet:** `0x3B` komutu (RGB888, 108 bayt) ve dinamik görsel komutları incelenecek. Flash'a yazdığı doğrulanırsa yalnızca kullanıcı butona bastığında, nadiren yazılacak.
- **2.4G dongle:** küçük bir spike ile `373B:11FF` ve 24 baytlık paketler test edilecek.
