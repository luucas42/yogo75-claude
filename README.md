# Yogo

ATK YOGO 75 PRO klavyesinin 6×6 ekranında Claude Code'un durumunu gösteren menü çubuğu uygulaması.

## Kurulum

```bash
scripts/build-app.sh --open      # derler, ~/Applications/Yogo.app'e kurar ve açar
```

Menü çubuğunda `✻` → **Claude Code hook'larını kur…** seçeneğini kullan. Bu işlem `~/.claude/settings.json` dosyasının yedeğini alır ve yalnızca Yogo'nun girdilerini ekler. Yeni hook'lar Claude Code oturumları yeniden başlatıldığında devreye girer.

## Kullanım

| Claude | Ekran |
|---|---|
| Düşünüyor | Kıvılcım nefes alıyor |
| Araç çalıştırıyor | Artı ve çarpı dönüyor |
| Onay bekliyor | Çift yanıp sönme |
| Bitti | Patlama ve yeşil halka, sonra klavyenin kendi efekti |

- **Editör (⌘E):** 6×6 çizim, kareler, PNG/GIF içe aktarma, "Duruma ata", "📌 Ekrana sabitle".
- **Terminal:**
  - `~/Applications/Yogo.app/Contents/MacOS/yogo simulate <thinking|tool|waiting|done|idle>`
  - `… yogo status`

## Bilinen kısıtlar

- Canlı ekran yalnızca **USB kabloyla** çalışır. Bluetooth'ta firmware'de ayar kanalı yok, 2.4G dongle ise henüz denenmedi (Faz 2).
- Bir izni onayladıktan sonra uzun süren bir araç, bitene kadar "onay bekliyor" olarak görünebilir. Claude Code onay anı için bir olay göndermiyor.
- Terminal `SessionEnd` gelmeden kapanırsa: menü → **Claude durumunu sıfırla**.
- "Oturum açılınca başlat" yeniden derlemelerden sonra da açık kalıyor (iki yeniden derlemeyle denendi).
- Mac uyuyup uyandıktan sonra yeniden bağlanma henüz denenmedi. Ekran Claude'a tepki vermiyorsa menüden Çıkış'a basıp Yogo'yu yeniden aç.
- Bluetooth rozeti ("Bluetooth · canlı mod kapalı") klavyenin Bluetooth kimliğine (36B0:3004) dayanıyor ve bu makinede henüz doğrulanmadı.

## Güvenlik

Yogo klavyeye yalnızca geçici canlı mod komutlarını gönderir: `0x10`, `0x11`, `0x3C` ve `0x3D`. Flash'a yazmaz, firmware arayüzüne dokunmaz. Klavye 0,5 saniye içinde kendi efektine döner.

## Günlük

`~/Library/Logs/Yogo/yogo.log`
