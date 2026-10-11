"""Eating and drinking's motion for Vibration (REST_MOTION in
ImprovedForever_Vibration/Vibration.lua): for each race and sex, the eat
animation's (EmoteEat, 61) length, and when the right hand (attachment 22)
reaches the mouth (attachment 17, Breath) and leaves it, from Forever's own
character models and animation files on wago.tools.

Run: python3 tools/make_rest_motion.py   (prints the table to paste)
"""
import math
import struct
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_library  # noqa: E402

API = make_library.API
BUILD = make_library.forever_build()
CACHE = Path(__file__).resolve().parent / ".models"

# The playable races' models (ChrModel: male, female)
MODELS = {1: (1011653, 1000764), 2: (917116, 949470), 3: (878772, 950080), 4: (974343, 921844),
          5: (959310, 997378), 6: (968705, 986648), 7: (900914, 940356), 8: (1022938, 1018060),
          95: (7478487, 7478494), 96: (7478487, 7478494)}
NAMES = {1: "Human", 2: "Orc", 3: "Dwarf", 4: "Night Elf", 5: "Undead", 6: "Tauren", 7: "Gnome", 8: "Troll",
         95: "High Order Skyborne", 96: "Windshaper Skyborne"}


def chunks(d):
    i=0; out={}
    while i+8<=len(d):
        tag=d[i:i+4].decode('latin1'); n=struct.unpack_from('<I',d,i+4)[0]
        out[tag]=(i+8,n); i+=8+n
    return out


def fetch(fid):
    """A file of Forever's build from wago.tools (cached in tools/.models)"""
    p = CACHE / f"{fid}.bin"
    if not p.exists():
        CACHE.mkdir(exist_ok=True)
        req = urllib.request.Request(f"{API}/api/casc/{fid}?version={BUILD}", headers={"User-Agent": "ImprovedForever-tools"})
        p.write_bytes(urllib.request.urlopen(req, timeout=120).read())
    return p.read_bytes()

def arr(d,o): return struct.unpack_from('<II',d,o)
def q16(v): return (v+32768 if v<0 else v-32767)/32767.0

class Model:
    def __init__(self,fid):
        d=fetch(fid)
        c=chunks(d); self.b=c['MD21'][0]; self.d=d
        self.afid={}
        if 'AFID' in c:
            s,n=c['AFID']
            for j in range(n//8):
                a,sub,f=struct.unpack_from('<HHI',d,s+j*8); self.afid[(a,sub)]=f
        b=self.b
        cnt,off=arr(d,b+0x1C)
        self.seqs=[]
        for k in range(cnt):
            o=b+off+k*64
            aid,var,dur=struct.unpack_from('<HHI',d,o)
            self.seqs.append((aid,var,dur))
        cnt,off=arr(d,b+0x2C)
        self.bones=[]
        for k in range(cnt):
            o=b+off+k*88
            key,flags,parent,sub=struct.unpack_from('<iIhH',d,o)
            tr=o+16; rot=o+36; sc=o+56
            piv=struct.unpack_from('<3f',d,o+76)
            self.bones.append(dict(key=key,parent=parent,tr=tr,rot=rot,sc=sc,piv=piv))
        cnt,off=arr(d,b+0xF0)
        self.att={}
        for k in range(cnt):
            o=b+off+k*40
            aid,bone,_=struct.unpack_from('<IHH',d,o)
            self.att[aid]=(bone,struct.unpack_from('<3f',d,o+8))
    def track(self,tro,si,kind,src):
        d=self.d; b=self.b
        tc,to=arr(d,tro+4); vc,vo=arr(d,tro+12)
        if si>=tc: return None
        n,toff=arr(d,b+to+si*8); _,voff=arr(d,b+vo+si*8)
        if n==0: return None
        buf,base=src
        ts=struct.unpack_from(f'<{n}I',buf,base+toff)
        if kind=='q':
            raw=struct.unpack_from(f'<{n*4}h',buf,base+voff)
            vals=[tuple(q16(x) for x in raw[i*4:i*4+4]) for i in range(n)]
        else:
            raw=struct.unpack_from(f'<{n*3}f',buf,base+voff)
            vals=[raw[i*3:i*3+3] for i in range(n)]
        return ts,vals
    def seq_index(self,aid,var=0):
        for k,(a,v,dur) in enumerate(self.seqs):
            if a==aid and v==var: return k,dur
    def load(self,aid,var=0):
        si,dur=self.seq_index(aid,var)
        f=self.afid.get((aid,var))
        if f:
            buf=fetch(f)
            c=chunks(buf) if buf[:4] in (b'AFM2',b'AFSA',b'AFSB') else None
            base=c['AFM2'][0] if c else 0
            src=(buf,base)
        else:
            src=(self.d,self.b)
        tracks=[]
        for bn in self.bones:
            tracks.append((self.track(bn['tr'],si,'v',src),self.track(bn['rot'],si,'q',src),self.track(bn['sc'],si,'v',src)))
        return dur,tracks

def sample(tr,t,default):
    if not tr: return default
    ts,vals=tr
    if t<=ts[0]: return vals[0]
    for i in range(1,len(ts)):
        if t<=ts[i]:
            a=(t-ts[i-1])/max(1,ts[i]-ts[i-1])
            return tuple(x+(y-x)*a for x,y in zip(vals[i-1],vals[i]))
    return vals[-1]

def qmat(q):
    x,y,z,w=q; n=math.sqrt(x*x+y*y+z*z+w*w) or 1; x,y,z,w=x/n,y/n,z/n,w/n
    return [[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]

def world(model,tracks,t):
    W=[None]*len(model.bones)
    for i,bn in enumerate(model.bones):
        tr,rot,sc=tracks[i]
        T=sample(tr,t,(0,0,0)); R=qmat(sample(rot,t,(0,0,0,1))); S=sample(sc,t,(1,1,1))
        p=bn['piv']
        # local: x -> p + T + R*S*(x-p)
        M=[[R[r][c]*S[c] for c in range(3)] for r in range(3)]
        off=[p[r]+T[r]-sum(M[r][c]*p[c] for c in range(3)) for r in range(3)]
        if bn['parent']>=0:
            PM,Po=W[bn['parent']]
            M2=[[sum(PM[r][k]*M[k][c] for k in range(3)) for c in range(3)] for r in range(3)]
            o2=[sum(PM[r][k]*off[k] for k in range(3))+Po[r] for r in range(3)]
            M,off=M2,o2
        W[i]=(M,off)
    return W

def point(W,bone,pos):
    M,o=W[bone]; return [sum(M[r][c]*pos[c] for c in range(3))+o[r] for r in range(3)]

def contact(fid,aid=61,hand=22,mouth=17,step=20):
    m=Model(fid)
    dur,tracks=m.load(aid)
    out=[]
    for t in range(0,dur+1,step):
        W=world(m,tracks,t)
        h=point(W,*m.att[hand]); mo=point(W,*m.att[mouth])
        out.append((t,math.dist(h,mo)))
    return dur,out


def motion(fid):
    """(length, reaches, leaves) in ms: the stretch around the closest point
    where the hand stays within 20% of its range from the mouth"""
    dur, out = contact(fid)
    out = out[:-1]
    n, step = len(out), out[1][0]
    lo, hi = min(d for _, d in out), max(d for _, d in out)
    th = lo + 0.2 * (hi - lo)
    i0 = min(range(n), key=lambda i: out[i][1])
    a = b = i0
    while out[(a - 1) % n][1] <= th and (a - 1) % n != i0:
        a -= 1
    while out[(b + 1) % n][1] <= th and (b + 1) % n != i0:
        b += 1
    leave = (b % n) * step
    return dur, (a % n) * step, leave if leave else dur


if __name__ == "__main__":
    print(f"-- {BUILD}")
    for race, files in MODELS.items():
        m, f = (motion(x) for x in files)
        print(f"    [{race}] = {{ {{ {m[0]}, {m[1]}, {m[2]} }}, {{ {f[0]}, {f[1]}, {f[2]} }} }},  -- {NAMES[race]}")
