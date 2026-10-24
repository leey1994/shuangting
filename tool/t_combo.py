# 盐 x appid/clientver 组合矩阵：/v9/login_by_pwd
import hashlib, json, urllib.request, urllib.parse, time, random, string
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad

SALTS = {"STD": "OIlwieks28dk2k092lksi2UIkp", "LITE": "LnT6xpN3khm36zse0QzvmgTZ3waWdRSA"}
N_LITE = int("C40A2D0DA76511F3BB1CC2BBD3AFBD8BEA83B4D6B05B6C13EB8920C53F1AF76793B2BA0D0EDB843240EF1B836EFED3EE240734C14C1399FD6594D16AF22F52525D14D72E0155C6DCC8638D4F7BB94F3A0B1F4C29F991972F2A160A25EB0A9E724336BE7F69BBD319FFAB1C6DD8470B021DC434F3FABA89F4A2A01B33BDBDD08B", 16)
N_STD = int("C8006ED03842D2628209BD314984CA5ED6CFE06E30C95F9D4704D9C49791D7A935BA950ECB0BC8EBF5F5994F0BAC927A7EB151B3C1DE343303FA539C83136ECCFD7D7E511E2DBCE18EAA9F784C9B50D443E75865979E0A5E216E46C684066A8D6B998580BBAA22D73F5790286BB14742E83244E44DB6D707FFE162C5C7002D45", 16)

def md5(s): return hashlib.md5(s.encode()).hexdigest()

T1 = "562a6f12a6e803453647d16a08f5f0c2ff7eee692cba2ab74cc4c8ab47fc467561a7c6b586ce7dc46a63613b246737c03a1dc8f8d162d8ce1d2c71893d19f1d4b797685a4c6d3d81341cbde65e488c4829a9b4d42ef2df470eb102979fa5adcdd9b4eecfea8b909ff7599abeb49867640f10c3c70fc444effca9d15db44a9a6c907731e2bb0f22cd9b3536380169995693e5f0e2424e3378097d3813186e3fe96bbe7023808a0981b4e2b6135a76faac"
T2 = "31c4daf4cf480169ccea1cb7d4a209295865a9d2b788510301694db229b87807469ea0d41b4d4b9173c2151da7294aeebfc9738df154bbdf11a4e117bb5dff6a3af8ce5ce333e681c1f29a44038f27567d58992eb81283e080778ac77db1400fdf49b7cf7e26be2e5af4da7830cc3be4"

mid = "".join(random.choice("0123456789abcdef") for _ in range(32))

def go(label, salt, appid, clientver, rsakey, dfid="-"):
    nowMs = int(time.time() * 1000)
    tk = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(16))
    k = md5(tk); iv = k[16:]
    ph = AES.new(k.encode(), AES.MODE_CBC, iv.encode()).encrypt(
        pad(json.dumps({"pwd": "WrongPass!1", "code": "", "clienttime_ms": nowMs}, separators=(',', ':')).encode(), 16)).hex()
    pk = format(pow(int.from_bytes(json.dumps({"clienttime_ms": nowMs, "key": tk}, separators=(',', ':')).encode(), 'big'), 65537, rsakey), 'x').rjust(256, '0').upper()
    body = {"plat": 1, "support_multi": 1, "clienttime_ms": nowMs, "t1": T1, "t2": T2,
            "t3": "MCwwLDAsMCwwLDAsMCwwLDA=", "username": "18800000000", "params": ph, "pk": pk}
    bj = json.dumps(body, separators=(',', ':'))
    ct = int(time.time())
    qp = {"appid": appid, "clientver": clientver, "clienttime": ct, "dfid": dfid, "mid": mid, "uuid": "-"}
    ps = "".join(f"{a}={qp[a]}" for a in sorted(qp))
    qp["signature"] = md5(salt + ps + bj + salt)
    h = {"Content-Type": "application/json;charset=utf-8",
         "User-Agent": "Android15-1070-11083-46-0-DiscoveryDRADProtocol-wifi",
         "dfid": dfid, "clienttime": str(ct), "mid": mid,
         "kg-rc": "1", "kg-thash": "5d816a0", "kg-rec": "1", "kg-rf": "B9EDA08A64250DEFFBCADDEE00F8F25F",
         "x-router": "login.user.kugou.com"}
    req = urllib.request.Request("https://gateway.kugou.com/v9/login_by_pwd?" + urllib.parse.urlencode(qp), data=bj.encode(), headers=h)
    try:
        print(label, urllib.request.urlopen(req, timeout=25).read().decode()[:160])
    except Exception as e:
        try: print(label, "HTTP", e.read().decode()[:100])
        except Exception: print(label, repr(e)[:100])

for sn, salt in SALTS.items():
    for (appid, cv) in [(1005, 20489), (1005, 20789), (3116, 11440)]:
        rn = "N_STD" if sn == "STD" else "N_LITE"
        go(f"#C {sn}/{appid}/{cv}/{rn}:", salt, appid, cv, N_STD if sn == "STD" else N_LITE)
# 盐与 rsa 交叉：lite盐+标准RSA
go("#C LITE盐/3116/STDrsa:", SALTS["LITE"], 3116, 11440, N_STD)
go("#C STD盐/1005/LITERSA:", SALTS["STD"], 1005, 20489, N_LITE)
