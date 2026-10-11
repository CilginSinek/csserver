# Yerel hesap protokolü

AMXX `account_guard` eklentisi, yalnızca loopback üzerinde dinleyen Python TCP servisine bağlanır. Servis stdlib `sqlite3` ve `hashlib.scrypt` kullanır; haricî Python paketi gerekmez. Her bağlantıda bir istek ve bir yanıt vardır. İstek/yanıt LF ile sonlanır, en fazla 1024 bayttır. İstek 3 saniyede tamamlanmalıdır. Aynı anda en fazla 8 servis işçisi çalışır.

Her istek `data/service.token` dosyasındaki 64 karakterlik rastgele token ile başlar. AMXX bunu özel `generated.cfg` içindeki `localinfo` üzerinden alır. Token, RCON şifresi ve kurucu şifresi ayrı değerlerdir. Token bir oyuncuya verilmez. Şifre ve nick UTF-8 baytlarının küçük harf hex kodlamasıyla taşınır; hex şifreleme değildir, aktarım yalnızca aynı makinededir.

```text
TOKEN|PING\n
TOKEN|AUTH|SESSION|IP|NICK_HEX|PASSWORD_HEX\n
TOKEN|RELEASE|SESSION\n
TOKEN|REGISTER|ACTOR_SESSION|NICK_HEX|PASSWORD_HEX\n
TOKEN|RESET|ACTOR_SESSION|NICK_HEX|PASSWORD_HEX\n
TOKEN|DELETE|ACTOR_SESSION|NICK_HEX|\n
```

`AUTH` sonucu `OK|GUEST|0` veya `OK|ACCOUNT|FLAGS` olur. FLAGS, AMXX `a..u` bitlerinin tamsayı toplamıdır. Misafir/normal oyuncunun admin flag değeri `0` olup eklenti AMXX `z` flagini atar. `REGISTER`, `RESET`, `DELETE` için güncel, doğrulanmış ve `l` flagine sahip ACTOR_SESSION gerekir. Başarılı değişiklik `OK|SAVED|0` döner. `PING` → `OK|PONG|0`, `RELEASE` → `OK|RELEASED|0`.

Hatalar `ERR|CODE`: `BAD_PASSWORD`, `RATE_LIMIT`, `ALREADY_CONNECTED`, `FORBIDDEN`, `EXISTS`, `NOT_FOUND`, `FOUNDER_PROTECTED`, `INVALID`, `RETRY`, `RELEASED`, `UNAVAILABLE`. Başarısız girişler nick başına 5/dakika, IP başına 20/dakika ile sınırlandırılır; doğrulanmış mevcut oturumlar dışarıdan yapılan denemeler nedeniyle kilitlenmez. Yönetim ve servis hataları hiçbir zaman misafir girişine dönüştürülmez.

Oturumlar RAM'dedir ve 20 saniye sonra yenilenmezse sona erer. AMXX her 5 saniyede şifreyi tekrar doğrular. Şifre/yetki değişikliği hesabın revision değerini artırır ve eski oturumun yönetim yetkisini hemen geçersiz kılar. `RELEASE`, o session ID için gecikmiş AUTH isteklerinin oturumu yeniden oluşturmasını engeller. Session ID her sunucu/harita/oyuncu katılımında yenilenir.

SQLite `accounts` tablosu: `nick_key` (Unicode casefold), görünen `nick`, 16 bayt salt, 32 bayt digest, tamsayı flags, founder işareti, revision. Şifre türetme: scrypt N=16384, r=8, p=1, dklen=32. Salt her kayıtta ve şifre değişikliğinde yenilenir; karşılaştırma sabit süreli `hmac.compare_digest` ile yapılır. En fazla bir founder kaydı bulunabilir. Ham şifreler ve protokol paketleri loglanmaz.

Gelecekte site entegrasyonu için mevcut `Store.change()` işlemleri ortak kayıt mantığıdır. Siteye bu yerel servis tokenını veya oyuncu session kimliğini vermek yerine ayrıca kimlik doğrulanan bir web API katmanı eklenmelidir. Şu an böyle bir web API uygulanmamıştır.
