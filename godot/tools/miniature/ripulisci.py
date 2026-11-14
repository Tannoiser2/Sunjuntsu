# Ricodifica le immagini del GLB in JPEG semplice (senza profilo ICC) e toglie l'emissivo.
import json,struct,sys,io
from PIL import Image
def main(src,dst):
    d=open(src,'rb').read(); n=struct.unpack('<I',d[12:16])[0]
    js=json.loads(d[20:20+n]); o=20+n; bl=struct.unpack('<I',d[o:o+4])[0]; b=d[o+8:o+8+bl]
    usati_emiss=set()
    for m in js.get('materials',[]):
        if 'emissiveTexture' in m: usati_emiss.add(m['emissiveTexture']['index']); del m['emissiveTexture']
        m.pop('emissiveFactor',None)
    nuovi={}
    for i,im in enumerate(js.get('images',[])):
        bv=js['bufferViews'][im['bufferView']]; s=bv.get('byteOffset',0)
        p=Image.open(io.BytesIO(b[s:s+bv['byteLength']])).convert('RGB')
        q=io.BytesIO(); p.save(q,'JPEG',quality=82,optimize=True); nuovi[im['bufferView']]=q.getvalue(); im['mimeType']='image/jpeg'
    out=bytearray()
    for k,bv in enumerate(js['bufferViews']):
        s=bv.get('byteOffset',0); dati=nuovi.get(k, b[s:s+bv['byteLength']])
        while len(out)%4: out.append(0)
        bv['byteOffset']=len(out); bv['byteLength']=len(dati); out+=dati
    while len(out)%4: out.append(0)
    js['buffers'][0]['byteLength']=len(out)
    j=json.dumps(js,separators=(',',':')).encode()
    while len(j)%4: j+=b' '
    tot=12+8+len(j)+8+len(out)
    open(dst,'wb').write(b'glTF'+struct.pack('<II',2,tot)+struct.pack('<I',len(j))+b'JSON'+j+struct.pack('<I',len(out))+b'BIN\x00'+bytes(out))
main(sys.argv[1],sys.argv[2])
