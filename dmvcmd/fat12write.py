import struct,sys
from fat12 import F12

def replace_file(imgpath,fname,newdata,outpath):
    f=F12(imgpath)
    d=bytearray(f.d)
    # find dir entry
    entoff=None;start=None;oldsize=None
    for i in range(f.ndir):
        o=f.rootoff+i*32
        e=d[o:o+32]
        if e[0] in (0,0xE5):continue
        if e[0x0b]&0x0F==0x0F:continue
        nm=bytes(e[0:8]).rstrip(b' ').decode('latin1')
        ex=bytes(e[8:11]).rstrip(b' ').decode('latin1')
        full=nm+('.'+ex if ex else '')
        if full.upper()==fname.upper():
            entoff=o;start=struct.unpack('<H',e[0x1a:0x1c])[0]
            oldsize=struct.unpack('<I',e[0x1c:0x20])[0];break
    if entoff is None:raise Exception("file not found: "+fname)
    # free old chain
    chain=f.chain(start)
    def setfat(n,val):
        off=f.fat0+(n*3)//2
        cur=d[off]|(d[off+1]<<8)
        if (n&1)==0:cur=(cur&0xF000)|(val&0xFFF)
        else:cur=(cur&0x000F)|((val&0xFFF)<<4)
        d[off]=cur&0xff;d[off+1]=(cur>>8)&0xff
        # mirror to 2nd FAT
        off2=off+f.spf*f.bps
        d[off2]=cur&0xff;d[off2+1]=(cur>>8)&0xff
    # collect free clusters: reuse old chain first, then scan for more free
    spc_bytes=f.spc*f.bps
    nclusters=(len(newdata)+spc_bytes-1)//spc_bytes
    # gather all currently-free clusters (value 0), plus the old chain (which we free)
    freeset=list(chain)
    total_clusters=(len(f.d)-f.dataoff)//spc_bytes+2
    for c in range(2,total_clusters):
        if c in chain:continue
        if f.fatent(c)==0:freeset.append(c)
    if len(freeset)<nclusters:raise Exception("not enough space")
    freeset=sorted(set(freeset))[:nclusters] if False else freeset
    # keep order: old chain first (locality), then others
    use=[]
    seen=set()
    for c in chain:
        if c not in seen:use.append(c);seen.add(c)
    for c in sorted([x for x in freeset if x not in seen]):
        use.append(c);seen.add(c)
    use=use[:nclusters]
    # first, zero the old chain in FAT (will be rewritten)
    for c in chain:setfat(c,0)
    # write data + link chain
    for idx,cl in enumerate(use):
        o=f.dataoff+(cl-2)*spc_bytes
        chunk=newdata[idx*spc_bytes:(idx+1)*spc_bytes]
        d[o:o+len(chunk)]=chunk
        if len(chunk)<spc_bytes:
            d[o+len(chunk):o+spc_bytes]=b'\x00'*(spc_bytes-len(chunk))
        if idx<len(use)-1:setfat(cl,use[idx+1])
        else:setfat(cl,0xFFF)
    # update dir entry: start cluster + size
    struct.pack_into('<H',d,entoff+0x1a,use[0])
    struct.pack_into('<I',d,entoff+0x1c,len(newdata))
    open(outpath,'wb').write(d)
    print(f"replaced {fname}: {oldsize} -> {len(newdata)} bytes, {len(use)} clusters starting at {use[0]}")

if __name__=='__main__':
    replace_file(sys.argv[1],sys.argv[2],open(sys.argv[3],'rb').read(),sys.argv[4])
