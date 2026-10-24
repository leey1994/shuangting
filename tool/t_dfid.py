# 密码登录签名变体二分：dfid/uuid/host 组合
import base64 as b64
import hashlib, json, urllib.request, urllib.parse, time, random, string, pickle
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad

ROUTE = "LnT6xpN3khm36zse0QzvmgTZ3waWdRSA"
N = int("C40A2D0DA76511F3BB1CC2BBD3AFBD8BEA83B4D6B05B6C13EB8920C53F1AF76793B2BA0D0EDB843240EF1B836EFED3EE240734C14C1399FD6594D16AF22F52525D14D72E0155C6DCC8638D4F7BB94F3A0B1F4C29F991972F2A160A25EB0A9E724336BE7F69BBD319FFAB1C6DD8470B021DC434F3FABA89F4A2A01B33BDBDD08B", 16)

def md5(s): return hashlib.md5(s.encode()).hexdigest()
def rsa_raw(s): return format(pow(int.from_bytes(s.encode(), 'big'), 65537, N), 'x').rjust(256, '0').upper()

T1 = "562a6f12a6e803453647d16a08f5f0c2ff7eee692cba2ab74cc4c8ab47fc467561a7c6b586ce7dc46a63613b246737c03a1dc8f8d162d8ce1d2c71893d19f1d4b797685a4c6d3d81341cbde65e488c4829a9b4d42ef2df470eb102979fa5adcdd9b4eecfea8b909ff7599abeb49867640f10c3c70fc444effca9d15db44a9a6c907731e2bb0f22cd9b3536380169995693e5f0e2424e3378097d3813186e3fe96bbe7023808a0981b4e2b6135a76faac"
T2 = "31c4daf4cf480169ccea1cb7d4a209295865a9d2b788510301694db229b87807469ea0d41b4d4b9173c2151da7294aeebfc9738df154bbdf11a4e117bb5dff6a3af8ce5ce333e681c1f29a44038f27567d58992eb81283e080778ac77db1400fdf49b7cf7e26be2e5af4da7830cc3be4"

dev = pickle.load(open('tool/dev.pkl', 'rb'))
mid, regdfid = dev['mid'], dev['dfid']

def go(label, dfid_q, uuid_q, url="https://gateway.kugou.com/v9/login_by_pwd", router=True):
    nowMs = int(time.time() * 1000)
    tk = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(16))
    k = md5(tk); iv = k[16:]
    ph = AES.new(k.encode(), AES.MODE_CBC, iv.encode()).encrypt(
        pad(json.dumps({"pwd": "WrongPass!1", "code": "", "clienttime_ms": nowMs}, separators=(',', ':')).encode(), 16)).hex()
    pk = rsa_raw(json.dumps({"clienttime_ms": nowMs, "key": tk}, separators=(',', ':')))
    body = {"plat": 1, "support_multi": 1, "clienttime_ms": nowMs, "t1": T1, "t2": T2,
            "t3": "MCwwLDAsMCwwLDAsMCwwLDA=", "username": "18800000000", "params": ph, "pk": pk}
    bj = json.dumps(body, separators=(',', ':'))
    ct = int(time.time())
    qp = {"appid": 3116, "clientver": 11440, "clienttime": ct, "dfid": dfid_q, "mid": mid, "uuid": uuid_q}
    ps = "".join(f"{a}={qp[a]}" for a in sorted(qp))
    qp["signature"] = md5(ROUTE + ps + bj + ROUTE)
    h = {"Content-Type": "application/json;charset=utf-8",
         "User-Agent": "Android15-1070-11083-46-0-DiscoveryDRADProtocol-wifi",
         "dfid": dfid_q, "clienttime": str(ct), "mid": mid,
         "kg-rc": "1", "kg-thash": "5d816a0", "kg-rec": "1", "kg-rf": "B9EDA08A64250DEFFBCADDEE00F8F25F"}
    if router: h["x-router"] = "login.user.kugou.com"
    req = urllib.request.Request(url + "?" + urllib.parse.urlencode(qp), data=bj.encode(), headers=h)
    try:
        print(label, urllib.request.urlopen(req, timeout=25).read().decode()[:200])
    except Exception as e:
        try: print(label, "HTTP", e.read().decode()[:120])
        except Exception: print(label, repr(e)[:120])

U = "http://login.user.kugou.com/v9/login_by_pwd"
G = "https://gateway.kugou.com/v9/login_by_pwd"
go('#D1 gw dfid=- uuid=-     ', '-', '-')
go('#D2 gw dfid=- uuid=mid   ', '-', mid)
go('#D3 gw dfid=reg uuid=-   ', regdfid, '-')
go('#D4 http dfid=- uuid=-   ', '-', '-', url=U, router=False)
go('#D5 http dfid=reg uuid=- ', regdfid, '-', url=U, router=False)
go('#D6 http dfid=- uuid=- norange', '-', '-', url="https://login.user.kugou.com/v9/login_by_pwd", router=False)
