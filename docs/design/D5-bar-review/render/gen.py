import re, sys, os
S=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R='/home/anatoly/projects/custom_barista'
H=os.path.expanduser('~')
src=open(R+'/config.toml').read().replace('~/projects', H+'/projects')
head, *blocks = re.split(r'(?m)^(?=\[\[block\]\]$)', src)
def key(b):
    m=re.search(r'(?m)^block = "(\w+)"',b); k=m.group(1)
    if k=='custom': k=re.search(r'scripts/([\w-]+)\.sh',b).group(1)
    if k=='net': k='net_wl' if '"^wl"' in b else 'net_en'
    return k
B={key(b):b for b in blocks}; ORDER=[key(b) for b in blocks]
def P2(B):
    for k in ('memory','disk_space','disk_iostats','net_en','net_wl'):
        B[k]=re.sub(r'\.eng\(prefix:([A-Za-z]),w:(\d)\)', r'.eng(prefix:\1,w:\2,hide_unit:true)', B[k])
    B['gpu']=B['gpu'].replace(R+'/scripts/gpu.sh', S+'/bin/gpu.sh')
def P3(B):
    b=B['net_en']; f=re.search(r'(?m)^format = .*$',b).group(0)
    B['net_en']=b.replace(f, f.replace(' $ip ',' ')+'\n'+f.replace('format =','format_alt =',1))
def P4(B):
    B['clip']=B['clip'].replace(R+'/scripts/clip.sh', S+'/bin/clip.sh')
def merge(B, keys):
    for k in keys: B[k]=re.sub(r'(?m)^(block = "\w+")$', r'\1\nmerge_with_next = true', B[k], count=1)
BORDER=['load','temperature','freq','memory','disk_space','disk_iostats','gpu','net_wl','net_en','claude-usage','clip','keyboard_layout','battery','sound','time']
MERGE_B=['load','temperature','memory','disk_space','net_wl','claude-usage','keyboard_layout','battery']
def C(head):
    head=head.replace('idle_fg = "#ffffff"','idle_fg = "#aaaaaa"\nseparator = "  "\nseparator_bg = "auto"\nseparator_fg = "auto"')
    return head
def build(name, fixes, order=None, mergekeys=(), head_fn=None):
    b=dict(B)
    for f in fixes: f(b)
    if mergekeys: merge(b, mergekeys)
    o=order or ORDER
    h=head_fn(head) if head_fn else head
    txt=h+''.join(b[k] if b[k].endswith('\n\n') else b[k]+'\n' for k in o)
    open(f'{S}/cfg/{name}.toml','w').write(txt)
    # compact: gen-compact rules + design fixes (P5, merge cleanup)
    out=[]
    for k in o:
        if k in ('disk_space','disk_iostats','claude-usage'): continue
        x=b[k]
        x=re.sub(r'(?m)^(format = .*) \$ip ', r'\1 ', x)
        out.append(x if x.endswith('\n\n') else x+'\n')
    # a merge flag must not leak across a dropped block: drop it when the next kept block is not the same group
    open(f'{S}/cfg/{name}-c.toml','w').write(h+''.join(out))
    return txt
P5=lambda t: t.replace("%a %Y-%m-%d","%a %m-%d")
build('cur',[])
build('p2',[P2]); build('p3',[P3]); build('p4',[P4])
build('f6',[],order=BORDER)
build('f7',[],mergekeys=['load','temperature','memory','disk_space'])
build('a',[P2,P3,P4]); build('b',[P2,P3,P4],order=BORDER,mergekeys=MERGE_B)
build('c',[P2,P3,P4],order=BORDER,mergekeys=MERGE_B,head_fn=C)
# compact fixes
for n in ('b','c','f7'):
    p=f'{S}/cfg/{n}-c.toml'; t=open(p).read()
    t=re.sub(r'(?m)^(block = "memory")\nmerge_with_next = true$', r'\1', t)   # disk/io dropped on DP-2
    open(p,'w').write(t)
for n in ('p5','a','b','c'):
    src_n = 'cur' if n=='p5' else n
    t=open(f'{S}/cfg/{src_n}-c.toml').read(); open(f'{S}/cfg/{n}-c.toml','w').write(P5(t))
