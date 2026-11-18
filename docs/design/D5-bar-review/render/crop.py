# crop.py IN OUT [i j] [--zoom N] [--tw W] [--start0] : status area or segments i..j (by separators), pad 10 px
import sys, numpy as np
from PIL import Image
args=sys.argv[1:]; opt={}
for o in ('--zoom','--tw'):
    if o in args: k=args.index(o); opt[o]=int(args[k+1]); del args[k:k+2]
start0='--start0' in args; args=[x for x in args if x!='--start0']
im=Image.open(args[0]).convert('RGB'); a=np.asarray(im).astype(int); h,w,_=a.shape
g=((a[:,:,0]==0x66)&(a[:,:,1]==0x66)&(a[:,:,2]==0x66)).sum(0)
seps=[x for x in range(w) if g[x]>=h*0.6]
lit=(a.max(2)>40).sum(0)>0
if start0: start=int(np.nonzero(lit)[0][0])
else:
    run=0; start=None
    for x in range(w):
        if lit[x]:
            if run>=150 and x>100: start=x; break
            run=0
        else: run+=1
end = seps[-1]+opt['--tw'] if '--tw' in opt else int(np.nonzero(lit)[0][-1])
edges=[start-1]+seps+[end+1]
if len(args)>=4: i,j=int(args[2]),int(args[3]); L,Rr=edges[i],edges[j+1]
else: L,Rr=edges[0],edges[-1]
L=max(0,L-10); Rr=min(w,Rr+11)
c=im.crop((L,0,Rr,h))
z=opt.get('--zoom',1)
if z>1: c=c.resize((c.width*z,c.height*z),Image.NEAREST)
c.save(args[1]); print(args[1].split('/')[-1], c.width, 'segs', len(edges)-1)
