# Kurulum doğrulaması

11 Ekim 2026 (Europe/Istanbul), Ubuntu 26.04.1 LTS, x86_64.

- Valve App 90 `steam_legacy` tabanı SteamCMD ile indirildi ve doğrulandı.
- ReHLDS 3.15.0.896, ReGameDLL 5.30.0.814, Metamod-R 1.3.0.149, AMXX 1.10.0.5486 ve Reunion 0.2.0.25 gerçek HLDS açılışında çalıştı.
- ReAPI arşiv etiketi 5.29.0.358; arşivdeki modül çalışma zamanında 5.29.0.359-dev bildiriyor. Gerçek modül listesinde `running` görüldü.
- `deathrun_temple` GoldSrc BSP sürüm 30. Harita worldspawn açıklaması: xPaw; standart halflife/decals kaynakları Valve tabanından geliyor. Sunucu haritayı eksik model/ses/harita hatası olmadan yükledi.
- Özel Pawn eklentileri ve ban kalıcılığı eklenmiş AMXX komut/menü/oylama kaynakları derlendi. Gerçek açılışta 19/19 AMXX eklentisi çalıştı; ReAPI, Sockets ve FakeMeta modülleri yüklendi.
- `sv_autobunnyhopping=1`, `sv_enablebunnyhopping=1` ve A2S sunucu sorgusu gerçek motor üzerinde doğrulandı. Steam sunucularına bağlantı kuruldu.
- 10 hesap testi ve 1 gerçek süreç yönetimi testi geçti. Süreç yönetimi testi özel geçici `.env` ve veritabanı kullanır; kurucu hesabınız oluşturulmaz.
- Gerçek AMX `amx_addban` ile iki dakikalık test IP banı oluşturuldu. Bitiş zamanı diske yazıldı; yeni HLDS sürecinde yaklaşık 1.9 dakika kalan süreyle yüklendi; `amx_unban` hem motor hem ek kayıt dosyasından kaldırdı. Test, önceki ban dosyalarını geri yükler.

Tekrarlama:

```bash
python3 tools/compile.py
python3 -m unittest discover -s tests -v
python3 tests/smoke_server.py
```

Testlerde oyun portları yalnızca loopback üzerinde 27025/27026, hesap servisi test portları 28766 veya geçici porttur. Canlı sunucu kapalı olmalıdır. Loglar `logs/smoke-server.log` ve `logs/smoke-ban-restart.log` altındadır.

Gerçek Steam/non-Steam oyun istemcileriyle henüz doğrulanmayanlar: yönetici kayıt menüsünün ekran akışı, `_pw` ile gerçek istemci bağlantısı, nick değişimini geri alma, iki oyuncuyla T/CT dönüşümü, tuzak kullanımı ve bhop hareketi. Bu kontroller için README'deki manuel test adımları kullanılmalıdır.

Kurucu `.env` alanları kullanıcı tarafından doldurulmak üzere boş bırakıldı; üretim sunucusu çalışır durumda bırakılmadı. Kalıcı sistem servisi veya güvenlik duvarı değişikliği uygulanmadı.
