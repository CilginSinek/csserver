# ReHLDS CS 1.6 Deathrun + Jailbreak sunucusu

Ubuntu x86_64 üzerinde Steam ve non-Steam istemciler için ReHLDS sunucusu. Açılış haritası **deathrun_temple**, 16 oyuncu, UDP 27015. Misafirler oynayabilir; kayıtlı nickler kişisel şifreyle korunur. GitHub deposu yalnızca kaynak ve yapılandırmaları içerir; SteamCMD ile oyun sunucusu ilk kurulumda indirilir.

## İlk kullanım

Projeyi GitHub’dan indirin ve kurucu bilgilerini özel `.env` dosyasına yazın:

```bash
git clone <GITHUB_REPO_URL> csserver
cd csserver
cp .env.example .env
nano .env
```

```dotenv
SERVER_NAME="CS 1.6 Deathrun"
SERVER_PORT=27015
MAX_PLAYERS=16
DEFAULT_MAP=deathrun_temple
SERVER_BIND=0.0.0.0
FOUNDER_NICK="SeninNickin"
FOUNDER_PASSWORD="GucluBirSifre123"
RCON_PASSWORD=""
ACCOUNT_PORT=28765
```

Nick en fazla 31 UTF-8 bayt olabilir. Türkçe karakterler birden fazla bayt kullanabilir. Şifre 8–63 UTF-8 bayt olmalı; çift tırnak, ters eğik çizgi veya `;` kullanmayın. Boşluk içeren `.env` değerlerini tırnak içine alın. `.env` kabuk betiği gibi çalıştırılmaz; `KEY=value` biçimiyle okunur. Dosya izinleri otomatik olarak `600` yapılır. Sunucuyu normal kullanıcıyla çalıştırın, sudo ile başlatmayın.

```bash
make setup
make run
make status
make stop
```

`make setup` SteamCMD, ReHLDS, ReGameDLL, Metamod-R, AMX Mod X, ReAPI, Reunion ve gereken harita/model kaynaklarını indirir, sonra eklentileri derler. İlk kurulumdan sonra `make` sunucuyu başlatır; eksik kurulum algılarsa önce setup çalıştırır. Setup sistem kitaplıklarını yüklemez; gerekli Ubuntu paketlerini aşağıdaki kurulum bölümündeki komutla yükleyin.

İlk başlatmada kurucu hesabı ve tam AMX yetkileri oluşturulur. Sonraki başlatmalar mevcut hesabın şifresini değiştirmez. `RCON_PASSWORD` boşsa güçlü bir şifre üretilip `data/rcon.secret` içinde saklanır. RCON, oyun hesabından ayrı bir sunucu konsolu yetkisidir.

Kurucu şifresini veya nickini `.env` üzerinden sonradan değiştirmek için:

```bash
./scripts/stop.sh
# .env içindeki FOUNDER_NICK ve FOUNDER_PASSWORD değerlerini düzenleyin.
python3 tools/account_admin.py sync-founder
./scripts/start.sh
```

Kurucu nicki değişirse önceki kurucu hesabı normal oyuncu hesabına dönüşür. Yeni nick zaten kayıtlıysa bu açık senkronizasyon işlemi onu kurucu hesabına dönüştürür.

## Sunucuya bağlanma

Kayıtlı oyuncu ve kurucu, **bağlanmadan önce oyun konsoluna** şunları yazar:

```text
name "SeninNickin"
setinfo "_pw" "GucluBirSifre123"
connect SUNUCU_IP:27015
```

Aynı makineden test için IP yerine `127.0.0.1`; aynı ağdan bağlantı için sunucunun yerel IP adresini kullanın. Konsolu genellikle `~` tuşuyla açabilirsiniz. İsterseniz `name` ve `setinfo` satırlarını kendi oyununuzun `cstrike/userconfig.cfg` dosyasına ekleyebilirsiniz.

Kayıtsız nick için şifre gerekmez:

```text
name "MisafirNick"
setinfo "_pw" ""
connect SUNUCU_IP:27015
```

Nick karşılaştırması büyük/küçük harf duyarsızdır (Unicode casefold); iç boşluklar korunur. Kayıtlı nickte eksik/yanlış şifre varsa oyuncu takıma katılamadan çıkarılır. Doğrulama yerel servise asenkron yapılır; bu sırada takım katılımı ve doğma engellenir. Bu kontrol GoldSrc bağlantı el sıkışmasından sonraki erken oyuncu katılımı aşamasındadır.

Canlı oturumda nick değişimi geri alınır. Yeni nick kullanmak için bağlantıyı kesip yeni nick ve şifreyle yeniden bağlanın. Aynı kayıtlı hesabın iki eşzamanlı oturumu kabul edilmez. Şifre/yetki durumu beş saniyede bir yeniden kontrol edilir; hesap servisi erişilemezse doğrulanan oyuncular da çıkarılır. `/giris` veya `/cikis` komutu yoktur.

`sv_password` ortak sunucu şifresidir; bu kurulumda boştur. Oyuncuya özel şifre için `_pw` kullanılır. [AMXX şifre alanı belgeleri](https://users.alliedmods.net/~amxmodx/doc/source/configuration/admins.htm)

## Yönetici: kayıt, şifre sıfırlama ve yetki

Kurucu giriş yaptıktan sonra sohbete `/kayit` veya `/kayıt` yazar:

1. **Nick kaydet**, **Şifre sıfırla** veya **Kaydı kaldır** seçilir.
2. Açılan `account_nick` alanına hedef nick yazılır; çevrimdışı nickler de kaydedilebilir.
3. Kayıt/sıfırlama için `account_password` alanına şifre yazılır. Silme ayrıca onay menüsü gösterir.

Şifre genel sohbete gönderilmez; giriş alanında yazan kişinin ekranında görünür. Menü yalnızca doğrulanmış ve `l` (ADMIN_RCON) yetkisine sahip hesaplara açıktır. Yeni kayıt normal oyuncudur; admin yetkisi otomatik verilmez. Oyuncular kendilerini kaydedemez. Kurucu kaydı menüden silinemez.

Sunucu terminalinden hesap yönetimi:

```bash
python3 tools/account_admin.py register --nick "Oyuncu"
python3 tools/account_admin.py reset --nick "Oyuncu"
python3 tools/account_admin.py grant --nick "Oyuncu" --flags "bcdefijmu"
python3 tools/account_admin.py list
python3 tools/account_admin.py delete --nick "Oyuncu"
```

Şifre terminalde gizli olarak sorulur; komut satırı argümanı olarak yazılmaz. `grant --flags ""` yönetici yetkilerini kaldırır. Aktif hesaplar en geç sonraki doğrulamada değişiklikten etkilenir; şifre sıfırlanan oyuncunun yeni şifreyle yeniden bağlanması gerekir. Kayıt kaldırılırsa nick tekrar misafir olarak kullanılabilir.

Yaygın yetkiler: `c` kick, `d` ban, `e` slap/slay, `f` harita, `i` yönetici sohbeti, `j` oylama, `l` RCON ve hesap yönetimi, `u` menü, `a` dokunulmazlık. Kurucu `a..u` yetkilerine sahiptir. Yetkiler `users.ini` üzerinden verilmez; **`admin.amxx` ve `admin_sql.amxx` açılmamalıdır**. Kimlik doğrulaması yalnızca hesap eklentisinden yapılır.

## Temel AMX komutları

Oyun konsolunda:

```text
amxmodmenu
amx_kick "Oyuncu" "Sebep"
amx_ban "Oyuncu" 30 "Sebep"
amx_ban "Oyuncu" 0 "Kalici ban"
amx_banip "Oyuncu" 30 "Sebep"
amx_unban "STEAM_0:1:123456"
amx_unban "192.0.2.10"
amx_addban "192.0.2.10" 30 "Sebep"
amx_slay "Oyuncu"
amx_slap "Oyuncu" 5
amx_map deathrun_temple
amx_say "Duyuru"
```

Ban komutlarında süre dakika, `0` kalıcıdır. Konsol, oyuncu menüsü ve yönetici oylamasındaki banlar `persistent_bans` ile saklanır; süreli banların bitiş zamanı sunucu kapalıyken de ilerler. Yeniden başlatmada kalan süre yüklenir. Doğrudan motor konsolundan verilen `banid`/`addip` komutları bu ek kayıt katmanından geçmez; kalıcılık için AMX komutlarını kullanın.

Steam oyuncularında SteamID banı kullanılabilir. Benzersiz kimliği olmayan eski non-Steam istemcilerinde Reunion IP tabanlı kimlik üretir; IP banı aynı ağdaki başka oyuncuları da etkileyebilir. Non-Steam kimliği hiçbir zaman tek başına admin yetkisi vermez. [AMX komut belgeleri](https://www.amxmodx.org/doc/source/commands/cmds.htm)

## Deathrun ve bunny hop

İki veya daha fazla doğrulanmış oyuncu olduğunda bir T tuzakları yönetir; diğer oyuncular CT olur. T seçimi oyuncu slotları arasında sırayla döner. Takım seçimi ve satın alma menüleri kapalıdır; oyuncular bıçakla doğar. Haritanın kendi bitiş silahları kalır. T ayrılırsa yeterli oyuncu olduğunda tur CT lehine sonlandırılır.

Tek oyuncu varken CT olarak serbest antrenman yapılır; ölen oyuncu yeniden doğar. İkinci oyuncu doğrulanınca tur yeniden başlatılır. Özel Deathrun düzeni yalnızca `deathrun_` ile başlayan haritalarda etkinleşir.

Auto-bhop Deathrun ve Jailbreak’te aktiftir; zıplama tuşunu basılı tutun. Her iki modda da `sv_autobunnyhopping`, `sv_enablebunnyhopping` ve `sv_airaccelerate 100` uygulanır. Bu ayarlar A/D + mouse ile hava kontrolünü artırır; yapay hız verme kodu değildir. Jailbreak’te havadayken jump’a bir kez daha basarak double-jump da yapılabilir. Diğer haritalarda vanilla hareket ayarları kullanılır. [ReGameDLL ayarları](https://rehlds.dev/docs/regamedll-cs/settings/)

## Jailbreak

Jailbreak modu `jail_`/`jb_` öneki olan veya `jail_maps.ini` içine yazılan haritalarda açılır. Deathrun için `deathrun_` öneki ya da `deathrun_maps.ini` kullanılır. Bu sınıflara girmeyen bütün haritalar Vanilla profilidir. `jail_buyukisyan_dark` Jailbreak listesinde yer alır; `istanbul_42_beta_v1` Jailbreak listesinden çıkarılmıştır ve Vanilla hareket ayarlarını kullanır. Harita menüsü ve mapcycle yalnız BSP’si bulunan ve worldspawn WAD bağımlılıkları sunucuda mevcut haritaları gösterir. Eksik WAD’lar `maps_blocked.ini` dosyasında listelenir; bu dosya her başlatmada yeniden üretilir. Harita `.res` dosyasına WAD bağımlılıkları da eklenir.

- CT oyuncusu `/komutcu` yazarak komutçuluğu alır; admin `amx_komutcu <oyuncu>` ile CT atayabilir.
- Komutçu `/hucreac` yazarak haritadaki `func_door` ve `func_door_rotating` kapılarını tetikler. Bazı haritalar hücre kapılarını özel targetname/button ile kontrol eder; bu haritalarda kapıyı haritaya özel ayarlamak gerekir.
- Son hayattaki T `/lr` ile bir CT seçip bıçak düellosu başlatabilir.
- Admin `/rev` ile ölü oyuncuları, `/rev <nick>` ile tek oyuncuyu tekrar doğurtabilir; konsol karşılığı `amx_rev [nick|@all]` ve `q` admin yetkisi ister.
- Takım seçimi kapalıdır. T oyuncuları başlangıçta yalnız bıçak taşır; ekipmanlarını `/jbmenu` veya varsayılan N tuşuyla açılan mahkum menüsünden TL karşılığı alabilir. TL başlangıçta 7, düşman öldürmede 3, headshot bonusunda 2 ve ölünce 2 artar; bakiyeler sunucu oturumu boyunca tutulur, çıkışta sıfırlanır. Menü sağlık, hız, ekstra zıplama, görünmezlik, CT ekranını karartma ve son mahkûm/LR koruması gözetilerek takım arkadaşını diriltme yetenekleri sunar. Fiyat ve ödül cvar’ları `jb_cash_*` ve `jb_price_*` ile değiştirilebilir.
- Herkes T başlar. Yaşayan CT `/ctmenu` ile komutçu, hücre, mahkûm diriltme, godmode ve yetkili roket menülerini açar. Warden/yetkili `/tsustum` ile aday oyununu açar veya kapatır; açıkken ilk `/tsustum` yazan doğrulanmış T CT olur. Yönetici oyuncu atamak için sohbetten `/team Oyuncu CT` veya konsoldan `amx_team Oyuncu CT` / `amx_teammenu` kullanabilir. Takım seçimi oyunculara kapalı kalır.
- Yetkili yönetici `/ayarlar` ile RedBull, hook, kar etkinliği, paraşüt ve Jailbreak menülerini geçici olarak açıp kapatabilir. Ayarlar harita profilindeki başlangıç değerlerine göre yeniden kurulur. Menü `q` (ADMIN_LEVEL_C) yönetici yetkisi ister.
- Jailbreak’te ikinci zıplama için havadayken zıplama tuşuna bir kez daha basın. Hayattaki CT oyuncusu `bind mouse3 +paint` ile basılı tutarak duvarlara renkli iz çizebilir; `-paint` tuş bırakılınca otomatik çağrılır. Süre `paint_marker_life_time` ile ayarlanır.
- Temel tur ayarları `config/jailbreak.cfg` içindedir; mod profilleri map değişiminde otomatik yüklenir. Özel isimli harita eklemek için `config/jail_maps.ini` veya çalışma anında `server/cstrike/addons/amxmodx/configs/jail_maps.ini` dosyasına BSP adını uzantısız ekleyin.

`istanbul_42_beta_v1` şu anda çalıştırılamaz: sunucu logunda `TEX_InitFromWad: couldn't open kampus_texture.wad` fatal hatası var. BSP worldspawn kaydı ayrıca `minecraft.wad`, `tekela1.wad`, `wood_s.wad`, `lego.wad` ve `wood_custom_pack.wad` istiyor; dokular BSP’ye gömülü değil ve bu dosyalar mevcut sunucu/arşivde bulunamadı. Harita güvenlik için menü/mapcycle listesinden çıkarılır; WAD’lar `server/cstrike/` içine eklendiğinde yeniden listelenir. Özel haritalar için overview metadatası varsa eksik `.bmp` dosyasına istemcinin dosya isteği hatası vermemesi için düşük ayrıntılı geçerli bir placeholder üretilir; bu placeholder haritanın gerçek üstten görünüşü değildir.

Bu, temel Jailbreak çekirdeğidir; haritaya özel hücre kapısı eşlemesi, mini oyunlar, komutçu menüsü ve daha zengin LR türleri sunucu mapine göre sonradan eklenebilir.

### Ortak RedBull, hook ve paraşüt

`/redbull` oyuncunun hız/yerçekimi ve can yenilemesini açıp kapatır. Orijinal RedBull davranışındaki gibi saniyede 1 can verir, 250 can üst sınırdır; `redbull_heal` ve `redbull_maxcan` ile ayarlanır. Hız/yerçekimi `redbull_maxspeed` ve `redbull_gravity` ile değişir; `sv_redbull 0` global olarak kapatır. Bu değerler Türkiye'de paylaşılan ReAPI örneğindeki ayarlara dayanır. [WEBAilesi RedBull örneği](https://www.webailesi.com/konu-cs-1-6-redbull-sv-redbull-kodu-ekleme-27554)

Hook yalnızca `t` (ADMIN_LEVEL_H) yetkili doğrulanmış adminlerde çalışır: sohbete `/hook` yazıp konsolda `bind f +hook` yapın; F basılıyken halat çizilir ve oyuncu baktığı noktaya çekilir, bırakınca durur. Aynı tuşu ayrıca `bind f -hook` ile bağlamayın; oyun tuş bırakılınca `-hook` komutunu kendisi gönderir. `+rope`/`-rope` ve `+grap`/`-grap` eş adları da desteklenir. Hook hızı `hook_speed` ile sınırlıdır. `amx_noclip <oyuncu>` veya sohbetten `/noclip <oyuncu>` komutu yalnızca `q` (ADMIN_LEVEL_C) yetkili yöneticiyle kullanılabilir.

Her oyuncu `/para` veya `/parasut` ile kendi paraşütünü açıp kapatabilir. Düşerken E (`+use`) tuşunu basılı tutunca canopy modeli açılır ve düşüş hızı `parachute_fallspeed` değerinde sınırlanır; tuş bırakılınca model kapanır. Admin hedef oyuncuya `amx_parasut <nick> 1|0` veya `/parasut <nick> 1|0` uygulayabilir. Model [GameBanana model 3225](https://gamebanana.com/models/3225) paketinden alınır, kurulumda GoldSrc biçimi doğrulanır ve `server/cstrike/models/parachute.mdl` konumuna kurulur.

### Kar topu etkinliği

`/snow 1` etkinliği başlatır, `/snow 0` durdurur (yetkili admin). Etkinlikte HE bombası kar topu gibi davranır: patlama hasarı engellenir ve isabet alan oyuncu iki saniye donar. Her oyuncu için atışlar arasında 1,5 saniye bekleme vardır; sınırsız HE ayarı açılmaz. Kar sprite yoğunluğu varsayılan olarak 6 saniyede en fazla 8 iz parçacığıdır (`snow_interval`, `snow_count`). Atılan bomba [w_snowball.mdl](server/cstrike/models/snowwars/v090/weapons/w_snowball.mdl) modelini kullanır; eldeki görünüm standart HE’dir. Model, MIT lisanslı Snow Wars deposundan alındı ve kaynak/atıf bilgisi `third_party/cs-snow-wars/` altındadır. Efekt özel map gerektirmez; kar temalı map yalnızca çevre sağlar.

## Sohbetten admin komutları

Sık komutları AMX ön eki olmadan sohbetten kullanın: `/map jail_buyukisyan_dark`, `/mapmenu`, `/team Oyuncu CT`, `/kick nick sebep`, `/ban nick dakika sebep`, `/slay nick`, `/slap nick 5`, `/noclip nick`, `/snow 1` ve `/snow 0`. Başka AMXX komutları `/amx_<komut> ...` biçiminde çalıştırılabilir. AMXX'in kendi yetki kontrolleri geçerlidir. Harita menüsü `maps.ini` listesini sunucu başlarken BSP dosyalarından yeniler; yeni BSP haritalar restart sonrası listede görünür.

Not: Eski Snowball War 3.05 sürümünün kaynak konusu AMXX 1.8+ ile FakeMeta/HamSandwich gereksinimlerini ve snow resource dosyalarını listeliyor; eski forum paketleri ReHLDS/ReGameDLL ile bu projede henüz denenmiş değildir. Bu kurulum, kaynak kodu burada tutulan AMXX eklentisini kullanır. [Snowball War gereksinimleri](https://forums.alliedmods.net/showthread.php?highlight=Snowball+war&t=82804)

## Make hedefleri

```bash
make setup   # .env ve kurucu hesabını kontrol edip sunucuyu kurar
make run     # sunucuyu başlatır
make stop    # sunucuyu durdurur
make status  # sunucu durumunu gösterir
make         # kurulum yoksa kurar, sonra başlatır; hazırsa doğrudan başlatır
make fclean  # .gitignore ile yok sayılan yerel dosyaları siler
```

`make setup` için `.env` içindeki kurucu şifresi geçerli olmalıdır. Setup tamamlandıktan sonra tekrar kurulum yapmak yerine `make run` kullanın.

`make fclean` geri alınamaz şekilde `.env`, hesap veritabanı/yetkileri, loglar, indirilmiş paketler ve kurulu oyun sunucusu dahil `.gitignore` kapsamındaki yerel dosyaları siler. Yalnızca temiz bir kurulum başlatmak istediğinizde çalıştırın; `.env.example` korunur.

## Yeni harita ekleme

Harita paketindeki klasör yapısını `server/cstrike/` altında koruyun:

| Dosya | Hedef |
|---|---|
| `yeni_harita.bsp` | `server/cstrike/maps/` |
| `.res`, `.txt`, `.nav` | `server/cstrike/maps/` |
| `.wad` | `server/cstrike/` |
| Modeller | `server/cstrike/models/` |
| Sesler | `server/cstrike/sound/` |
| Sprite dosyaları | `server/cstrike/sprites/` |
| Gökyüzü dosyaları | `server/cstrike/gfx/env/` |

Linux dosya adları büyük/küçük harfe duyarlıdır. Harita adını uzantısız olarak `server/cstrike/mapcycle.txt` içine ayrı satırda ekleyin. Menü/oylama listesi için `server/cstrike/addons/amxmodx/configs/maps.ini` dosyasına da ekleyin. Açılış haritasını `.env` içindeki `DEFAULT_MAP` ile değiştirebilirsiniz.

```bash
python3 tools/server.py console "changelevel deathrun_yeni"
```

Mapcycle'a harita eklemek oyun modunu değiştiren eklentiyi otomatik kurmaz. Deathrun düzeni `deathrun_` önekiyle etkinleşir. Haritanın `.res` dosyası ek kaynakların indirilmesini listeler; gerekiyorsa her satırda `cstrike` içinden başlayan yol yazın, örneğin `models/player/runner/runner.mdl`. Varsayılan `sv_allowdownload 1` ile indirme sunucudan yapılır. FastDL URL'si ayrıca yapılandırılabilir.

## Plugin ekleme ve derleme

Derlenmiş `.amxx` dosyasını `server/cstrike/addons/amxmodx/plugins/` içine koyun. Kaynağı `.sma` ise `server/cstrike/addons/amxmodx/scripting/` içine, gerekli `.inc` dosyalarını bunun `include/` altına yerleştirin:

```bash
cd server/cstrike/addons/amxmodx/scripting
./amxxpc yeni_plugin.sma -iinclude -o../plugins/yeni_plugin.amxx
```

Ardından `server/cstrike/addons/amxmodx/configs/plugins.ini` dosyasına `yeni_plugin.amxx` satırı ekleyip harita değiştirin veya sunucuyu yeniden başlatın. Başına `;` koymak eklentiyi devre dışı bırakır. Eklentinin gerektirdiği modüller `modules.ini` üzerinden etkinleştirilebilir; bu kurulumdaki ReAPI, Sockets ve FakeMeta otomatik yüklenir. Hesap eklentisini ilk sırada, `persistent_bans` eklentisini yönetim eklentilerinden önce tutun.

Bu projenin özel kaynakları `plugins/` altında; hepsini ve ban kalıcılığı için değiştirilmiş standart AMX komut/menü/oylama eklentilerini derlemek için:

```bash
python3 tools/compile.py
```

AMXX derleyicisi bazı hatalarda sıfır çıkış kodu verebilir; betik derleyici çıktısını da kontrol eder. Standart AMX kaynaklarının lisansları korunur. Üçüncü taraf eklenti kurarken hesabın admin yetkilerini nicke bakarak veren başka bir eklenti açmayın.

## Model ekleme

Oyuncu modeli örneği:

```text
server/cstrike/models/player/runner/runner.mdl
```

Model paketinde `runnerT.mdl` gibi ek doku dosyaları varsa bunları da aynı klasöre koyun. Dosyayı kopyalamak tek başına oyuncunun modelini değiştirmez: modelin harita başlangıcında **precache** edilmesi ve eklenti tarafından oyuncuya atanması gerekir.

`examples/custom_player_model.sma` CT oyuncularına `runner` modelini atayan örnektir. Önce kendi model dosyanızı yerleştirin; örneği scripting klasörüne kopyalayıp derleyin ve `plugins.ini` içinde Deathrun eklentilerinden sonra etkinleştirin. Model dosyası olmadığı için örnek varsayılan olarak açık değildir.

Silah modeli farklıdır: `v_*.mdl` birinci şahıs, `p_*.mdl` dışarıdan görünen, `w_*.mdl` yerdeki modeldir. Bunları `models/` içine koyup ilgili silahın deploy/yer modeli olaylarını yöneten bir model değiştirme eklentisiyle precache ve atama yapın. Oyuncu modeli örneği silah modellerini değiştirmez.

## Konsol, loglar ve ağ

```bash
python3 tools/server.py console "version"
python3 tools/server.py console "meta list"
python3 tools/server.py console "amxx plugins"
python3 tools/server.py console "amxx modules"
tail -f logs/server.log
```

`logs/server.log` sunucu konsolu, `logs/supervisor.log` süreç yönetimi, `logs/accounts.log` şifresiz hesap işlem denetimi, `logs/accounts-process.log` hesap servisi başlangıç hatalarını içerir. AMXX hata dosyaları `server/cstrike/addons/amxmodx/logs/` altındadır. Log dosyaları zamanla büyür; arşivleyebilir veya sistem logrotate yapılandırmasına ekleyebilirsiniz.

İnternet oyuncuları için seçtiğiniz **UDP oyun portunu** güvenlik duvarında açıp gerekiyorsa modemde sunucu makinesine yönlendirin. Varsayılan port `27015/udp`:

```bash
sudo ufw allow 27015/udp
```

Hesap servisi yalnızca `127.0.0.1:28765` üzerinde TCP dinler; bu portu internete açmayın. Makinenin Steam'e dışarı doğru erişimi de açık olmalıdır. NAT veya CGNAT durumunda sadece UFW kuralı dış erişim sağlamaz.

## GitHub deposu ve SteamCMD klasörleri

Depoya `csserver` içindeki kaynak dosyaları, `config/`, `plugins/`, `tools/`, `scripts/`, `tests/`, dokümantasyon ve `versions.json` eklenir. `.gitignore`; `.env`, hesap/ban verileri, loglar, çalışma durumu, indirme önbelleği, kurulu sunucu ve yerel runtime kitaplıklarını dışarıda tutar. `.env.example` depoda kalır; kurucu şifresini veya gerçek `.env` dosyasını GitHub'a koymayın.

`downloads/steamcmd` kurulumun indirdiği SteamCMD ve bileşen arşivlerini saklar. `server/` çalıştırılan HLDS/ReHLDS oyun dosyalarıdır. `runtime/` Ubuntu 32-bit uyumlu kitaplıklarını içerir. Bunlar depoya yüklenmez; yeni makinede `make setup` yeniden oluşturur.

## Yeni makineye kurulum ve güncelleme

```bash
sudo apt-get update
sudo apt-get install -y python3 curl unzip libc6-i386 lib32stdc++6 lib32gcc-s1
git clone <GITHUB_REPO_URL> csserver
cd csserver
cp .env.example .env
nano .env
make setup
make run
```

Valve tabanı **`app_update 90 -beta steam_legacy validate`** ile kurulur; normal yıldönümü dalı bu ReHLDS paketiyle uyumlu değildir. SteamCMD ilk kendini güncellerken yeniden çalıştırma gerekebilir; betik bunu tekrar dener. Steam SDK bağlantısı sunucuyu çalıştıran kullanıcının `~/.steam/sdk32/steamclient.so` yolunda oluşturulur. [ReHLDS kurulum belgesi](https://rehlds.dev/docs/rehlds/install/)

`versions.json` sürümleri, kaynak URL'leri ve SHA256 değerlerini sabitler. Valve tabanı ve SteamCMD kendi dağıtım sistemiyle güncellenir; tamamen sabit bir Valve sürümü vaat edilmez. Bileşen güncellemeden önce sunucuyu durdurup yedek alın. SteamCMD doğrulaması motor dosyalarını geri yazabilir; ardından ReHLDS katmanını tekrar kurmak gerekir. AMXX yapılandırmaları overlay aşamasında korunur; SteamCMD'nin kendi dosyalarında yapacağı değişiklikler için de yedek kullanın.

Başka bir makinede proje yolu farklıysa örnek systemd dosyasındaki yolları ve kullanıcıyı düzenleyin. Elle başlatılan sunucuyu önce durdurun:

```bash
sudo cp config/cs-deathrun.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now cs-deathrun
sudo systemctl status cs-deathrun
```

Bu servis örneği verilmiştir; kurulum klasörünüzü ve kullanıcıyı kendi makinenize göre ayarlayın. Bu kurulumda otomatik açılış etkinleştirilmemiştir. Hem systemd hem `start.sh` aynı kilidi kullanır; iki sunucu aynı anda başlatılmaz.

## Yedekleme

Sunucuyu durdurup `.env`, `data/`, `server/cstrike/reunion.cfg`, AMXX yapılandırmaları, `banned.cfg`, `listip.cfg` ve `server/cstrike/addons/amxmodx/data/persistent_bans.txt` dosyasını yedekleyin. Kendi harita/model/plugin dosyalarınızı da yedeğe ekleyin. SQLite veritabanı `data/accounts.sqlite3` içindedir; WAL/SHM dosyaları varsa bunları da birlikte koruyun. Çalışan veritabanının tek dosyasını kopyalamak yerine SQLite backup API'si kullanın veya sunucuyu önce durdurun.

## Testler ve bilinen doğrulama sınırı

```bash
python3 -m unittest discover -s tests -v
python3 tests/smoke_server.py
```

Hesap testleri misafir/kayıtlı girişini, yanlış şifreyi, yetkisiz kaydı, şifre sıfırlamayı, kayıt kaldırmayı, kurucu kalıcılığını, giriş sınırını, aynı hesabın eşzamanlı bağlantısını ve TCP protokolünü doğrular. Süreç testi başlatma/durdurma, çift başlatma engeli, konsol komutu ve hesap servisi kapanınca HLDS'nin de durmasını kontrol eder. Smoke testi geçici bir hesap veritabanıyla gerçek HLDS'yi loopback üzerinde açar, süreli banı kaydeder ve yeni motor sürecinde kalan süreyle yüklendiğini doğrular; kullanıcı `.env` değerlerini kullanmaz. Bu testler canlı sunucu açıkken çalıştırılmaz.

Gerçek oyun istemcileriyle şu kontroller ayrıca yapılmalıdır: Steam ve non-Steam giriş; yönetici kayıt menüsü; kayıtlı nickte eksik/yanlış/doğru `_pw`; canlı nick değişimi; iki oyuncuyla T dönüşümü, tuzaklar ve tur geçişi; zıplama tuşunu basılı tutarak bhop. Otomatik açılış testi oyuncunun fiziksel oyun hareketlerini doğrulamaz.

Yaygın hatalar: `32 bit runtime yok` → bağımlılıkları kurun; `SteamGameServer_Init` → Valve `steam_legacy` tabanını ve ReHLDS katmanını tekrar kurun; `Unable to initialize Steam` → kullanıcı Steam SDK bağlantısını kontrol edin; `bad load` → eklenti/modül sürümü ve include dosyalarını kontrol edin; `Mod_NumForName` → harita/model bağımlılığı eksiktir; `FOUNDER_NICK doldurulmali` → `.env` kurucu alanlarını doldurun.

İleride site üzerinden kayıt için yerel hesap servisinin aynı kayıt işlemleri kullanılabilir. Şu an dışa açık kayıt API'si veya site bulunmaz; protokol ayrıntıları [docs/account-protocol.md](docs/account-protocol.md) dosyasındadır.
