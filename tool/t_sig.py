# 定位 20006：android盐 vs register(1014) vs web；分别打 login_by_pwd / send_mobile_code
import hashlib, json, urllib.request, urllib.parse, time, random, string
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad

LITE = "LnT6xpN3khm36zse0QzvmgTZ3waWdRSA"
N_LITE = int("C40A2D0DA76511F3BB1CC2BBD3AFBD8BEA83B4D6B05B6C13EB8920C53F1AF76793B2BA0D0EDB843240EF1B836EFED3EE240734C14C1399FD6594D16AF22F52525D14D72E0155C6DCC8638D4F7BB94F3A0B1F4C29F991972F2A160A25EB0A9E724336BE7F69BBD319FFAB1C6DD8470B021DC434F3FABA89F4A2A01B33BDBDD08B", 16)
WEB = "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt"
def md5(s): return hashlib.md5(s.encode()).hexdigest()
def rsa(s): return format(pow(int.from_bytes(s.encode(),'big'),65537,N_LITE),'x').rjust(256,'0').upper()
T1="562a6f12a6e803453647d16a08f5f0c2ff7eee692cba2ab74cc4c8ab47fc467561a7c6b586ce7dc46a63613b246737c03a1dc8f8d162d8ce1d2c71893d19f1d4b797685a4c6d3d81341cbde65e488c4829a9b4d42ef2df470eb102979fa5adcdd9b4eecfea8b909ff7599abeb49867640f10c3c70fc444effca9d15db44a9a6c907731e2bb0f22cd9b3536380169995693e5f0e2424e3378097d3813186e3fe96bbe7023808a0981b4e2b6135a76faac"
T2="31c4daf4cf480169ccea1cb7d4a209295865a9d2b788510301694db229b87807469ea0d41b4d4b9173c2151da7294aeebfc9738df154bbdf11a4e117bb5dff6a3af8ce5ce333e681c1f29a44038f27567d58992eb81283e080778ac77db1400fdf49b7cf7e26be2e5af4da7830cc3be4"
mid="".join(random.choice("0123456789abcdef") for _ in range(32))

def send_sig(label, path, body, scheme, dfid="-", router="login.user.kugou.com"):
    nowMs=int(time.time()*1000)
    ct=int(time.time())
    qp={"appid":3116,"clientver":11440,"clienttime":ct,"dfid":dfid,"mid":mid,"uuid":"-"}
    bj=json.dumps(body,separators=(',',':'))
    ps="".join(f"{a}={qp[a]}" for a in sorted(qp))
    if scheme=="android": qp["signature"]=md5(LITE+ps+bj+LITE)
    elif scheme=="register":
        vals=sorted(str(qp[a]) for a in qp); qp["signature"]=md5("1014"+"".join(vals)+"1014")
    elif scheme=="web": qp["signature"]=md5(WEB+ps+WEB)
    h={"Content-Type":"application/json;charset=utf-8","User-Agent":"Android15-1070-11083-46-0-DiscoveryDRADProtocol-wifi","dfid":dfid,"clienttime":str(ct),"mid":mid,"kg-rc":"1","kg-thash":"5d816a0","kg-rec":"1","kg-rf":"B9EDA08A64250DEFFBCADDEE00F8F25F"}
    if router: h["x-router"]=router
    req=urllib.request.Request("https://gateway.kugou.com"+path+"?"+urllib.parse.urlencode(qp),data=bj.encode(),headers=h)
    try: print(label,urllib.request.urlopen(req,timeout=25).read().decode()[:140])
    except Exception as e:
        try: print(label,"HTTP",e.read().decode()[:90])
        except Exception: print(label,repr(e)[:90])

def pwd_body():
    nowMs=int(time.time()*1000)
    tk="".join(random.choice(string.ascii_lowercase+string.digits) for _ in range(16)); k=md5(tk);iv=k[16:]
    ph=AES.new(k.encode(),AES.MODE_CBC,iv.encode()).encrypt(pad(json.dumps({"pwd":"x","code":"","clienttime_ms":nowMs},separators=(',',':')).encode(),16)).hex()
    pk=rsa(json.dumps({"clienttime_ms":nowMs,"key":tk},separators=(',',':')))
    return {"plat":1,"support_multi":1,"clienttime_ms":nowMs,"t1":T1,"t2":T2,"t3":"MCwwLDAsMCwwLDAsMCwwLDA=","username":"18800000000","params":ph,"pk":pk}

def sms_body():
    nowMs=int(time.time()*1000)
    tk="".join(random.choice(string.ascii_lowercase+string.digits) for _ in range(16)); k=md5(tk);iv=k[16:]
    ph=AES.new(k.encode(),AES.MODE_CBC,iv.encode()).encrypt(pad(json.dumps({"mobile":"10000000000"},separators=(',',':')).encode(),16)).hex()
    pk=rsa(json.dumps({"clienttime_ms":nowMs,"key":tk},separators=(',',':')))
    return {"plat":"1","businessid":5,"clienttime_ms":nowMs,"pk":pk,"mobile":"10*****0","params":ph}

for sc in ["android","register","web"]:
    send_sig(f"#PWD {sc:9}:", "/v9/login_by_pwd", pwd_body(), sc)
for sc in ["android","register","web"]:
    send_sig(f"#SMS {sc:9}:", "/v8/send_mobile_code", sms_body(), sc)
