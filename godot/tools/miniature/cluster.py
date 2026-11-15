# Semplificazione a griglia (vertex clustering) per modelli troppo pesanti per Blender.
import json, struct, sys, numpy as np
sys.path.insert(0, '.')
from glbimg import leggi
src, dst, vox = sys.argv[1], sys.argv[2], float(sys.argv[3])
js, b = leggi(src)
def acc(i, n):
    a = js['accessors'][i]; bv = js['bufferViews'][a['bufferView']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a['componentType']]
    return np.frombuffer(b, dt, a['count'] * n, off).reshape(-1, n) if n > 1 else np.frombuffer(b, dt, a['count'], off)
pr = js['meshes'][0]['primitives'][0]
P = acc(pr['attributes']['POSITION'], 3); N = acc(pr['attributes']['NORMAL'], 3); T = acc(pr['attributes']['TEXCOORD_0'], 2)
I = acc(pr['indices'], 1).reshape(-1, 3)
q = np.floor((P - P.min(0)) / vox).astype(np.int64)
qu = np.floor(T * 48).astype(np.int64)
key = ((q[:, 0] * 1000003 + q[:, 1] * 1009 + q[:, 2]) * 1000033 + qu[:, 0] * 131 + qu[:, 1])
uk, rep, inv = np.unique(key, return_index=True, return_inverse=True)
# posizione = media della cella, uv e normale del rappresentante
cnt = np.bincount(inv).astype(np.float64)
pos = np.stack([np.bincount(inv, P[:, k]) / cnt for k in range(3)], 1).astype(np.float32)
nor = N[rep]; uv = np.stack([np.bincount(inv, T[:, k]) / cnt for k in range(2)], 1)
J = inv[I]
ok = (J[:, 0] != J[:, 1]) & (J[:, 1] != J[:, 2]) & (J[:, 0] != J[:, 2])
J = J[ok]
J = np.unique(np.sort(J, 1) * 0 + J, axis=0) if False else J
s = np.sort(J, 1); _, u = np.unique(s, axis=0, return_index=True); J = J[np.sort(u)].astype(np.uint32)
print('vertici', len(pos), 'triangoli', len(J))
# immagine
img = js['images'][0]; bv = js['bufferViews'][img['bufferView']]; o = bv.get('byteOffset', 0)
imgb = b[o:o + bv['byteLength']]
parti = [pos.tobytes(), nor.astype(np.float32).tobytes(), uv.astype(np.float32).tobytes(), J.tobytes(), imgb]
views = []; out = bytearray()
for p in parti:
    while len(out) % 4: out.append(0)
    views.append({'buffer': 0, 'byteOffset': len(out), 'byteLength': len(p)}); out += p
while len(out) % 4: out.append(0)
for k in range(4): views[k]['target'] = 34962 if k < 3 else 34963
nj = {'asset': {'version': '2.0'}, 'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0}],
      'meshes': [{'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2}, 'indices': 3, 'material': 0}]}],
      'materials': js['materials'][:1], 'textures': js['textures'], 'images': [{'mimeType': img['mimeType'], 'bufferView': 4}],
      'samplers': js.get('samplers', [{}]),
      'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3', 'min': pos.min(0).tolist(), 'max': pos.max(0).tolist()},
                    {'bufferView': 1, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3'},
                    {'bufferView': 2, 'componentType': 5126, 'count': len(pos), 'type': 'VEC2'},
                    {'bufferView': 3, 'componentType': 5125, 'count': J.size, 'type': 'SCALAR'}],
      'bufferViews': views, 'buffers': [{'byteLength': len(out)}]}
jj = json.dumps(nj).encode()
while len(jj) % 4: jj += b' '
open(dst, 'wb').write(b'glTF' + struct.pack('<II', 2, 12 + 8 + len(jj) + 8 + len(out)) + struct.pack('<I', len(jj)) + b'JSON' + jj + struct.pack('<I', len(out)) + b'BIN\x00' + bytes(out))
