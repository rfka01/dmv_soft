import struct,sys
class F12:
    def __init__(s,fn):
        s.d=bytearray(open(fn,'rb').read())
        s.bps=struct.unpack('<H',s.d[0x0b:0x0d])[0]
        s.spc=s.d[0x0d]; s.rsvd=struct.unpack('<H',s.d[0x0e:0x10])[0]
        s.nfat=s.d[0x10]; s.ndir=struct.unpack('<H',s.d[0x11:0x13])[0]
        s.spf=struct.unpack('<H',s.d[0x16:0x18])[0]
        s.fat0=s.rsvd*s.bps
        s.rootoff=(s.rsvd+s.nfat*s.spf)*s.bps
        s.rootsz=s.ndir*32
        s.dataoff=s.rootoff+s.rootsz
    def fatent(s,n):
        off=s.fat0+(n*3)//2
        v=s.d[off]|(s.d[off+1]<<8)
        return (v&0xFFF) if (n&1)==0 else (v>>4)
    def chain(s,start):
        c=[]; n=start
        while 2<=n<0xFF0:
            c.append(n); n=s.fatent(n)
        return c
    def root(s):
        ents=[]
        for i in range(s.ndir):
            e=s.d[s.rootoff+i*32:s.rootoff+i*32+32]
            if e[0]==0: break
            if e[0]==0xE5: continue
            attr=e[0x0b]
            if attr&0x0F==0x0F: continue
            name=bytes(e[0:8]).rstrip(b' ').decode('latin1')
            ext=bytes(e[8:11]).rstrip(b' ').decode('latin1')
            fn=name+('.'+ext if ext else '')
            start=struct.unpack('<H',e[0x1a:0x1c])[0]
            size=struct.unpack('<I',e[0x1c:0x20])[0]
            ents.append((fn,attr,start,size))
        return ents
    def read(s,start,size):
        out=bytearray()
        for cl in s.chain(start):
            o=s.dataoff+(cl-2)*s.spc*s.bps
            out+=s.d[o:o+s.spc*s.bps]
        return bytes(out[:size])
if __name__=='__main__':
    f=F12(sys.argv[1])
    for fn,attr,st,sz in f.root():
        print(f"{fn:14s} attr={attr:#04x} clus={st:4d} size={sz}")
