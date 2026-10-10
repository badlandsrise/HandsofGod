"""Bake a body-region mask into COLOR_0 of the base character body mesh.

R = height / total height, G = min(|x| / height * 2, 1), B = 1 if front (z > 0) else 0.
The villager shader cuts tunic, sleeves, belt and foot wraps from these values.
Overwrites the existing COLOR_0 bytes (UNSIGNED_BYTE normalized VEC4) in place.
"""
import json, struct, sys, os

for gltf_path in sys.argv[1:]:
    j = json.load(open(gltf_path))
    bin_path = os.path.join(os.path.dirname(gltf_path), j['buffers'][0]['uri'])
    data = bytearray(open(bin_path, 'rb').read())
    acc, views = j['accessors'], j['bufferViews']
    # the body is the primitive with the most vertices
    body = max((p for m in j['meshes'] for p in m['primitives']), key=lambda p: acc[p['attributes']['POSITION']]['count'])
    pa = acc[body['attributes']['POSITION']]; ca = acc[body['attributes']['COLOR_0']]
    assert pa['componentType'] == 5126 and ca['componentType'] == 5121 and ca['type'] == 'VEC4'
    pv = views[pa['bufferView']]; cv = views[ca['bufferView']]
    po = pv.get('byteOffset', 0) + pa.get('byteOffset', 0)
    co = cv.get('byteOffset', 0) + ca.get('byteOffset', 0)
    n = pa['count']
    H = pa['max'][1]
    for i in range(n):
        x, y, z = struct.unpack_from('<fff', data, po + i * 12)
        r = max(0, min(255, round(y / H * 255)))
        g = max(0, min(255, round(min(abs(x) / H * 2, 1) * 255)))
        b = 255 if z > 0 else 0
        struct.pack_into('<BBBB', data, co + i * 4, r, g, b, 255)
    open(bin_path, 'wb').write(data)
    print(gltf_path, 'verts', n, 'H', H)
