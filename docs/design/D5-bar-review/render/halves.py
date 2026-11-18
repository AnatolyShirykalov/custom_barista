import sys, numpy as np
from PIL import Image
im=Image.open(sys.argv[1]).convert('RGB'); a=np.asarray(im).astype(int); h,w,_=a.shape
g=((a[:,:,0]==0x66)&(a[:,:,1]==0x66)&(a[:,:,2]==0x66)).sum(0)
seps=[x for x in range(w) if g[x]>=h*0.6]
if not seps:  # no separators: split at the widest dark gap near the middle
    lit=(a.max(2)>40).sum(0)>0; best=None
    for x in range(int(w*.35),int(w*.65)):
        if not lit[x]:
            r=x
            while r<w and not lit[r]: r+=1
            if best is None or r-x>best[1]: best=(x,r-x)
    m=best[0]+best[1]//2
else: m=min(seps,key=lambda s:abs(s-w/2))
o=sys.argv[2]; im.crop((0,0,m+1,h)).save(o+'-1.png'); im.crop((m,0,w,h)).save(o+'-2.png'); print(o.split('/')[-1], m, w)
