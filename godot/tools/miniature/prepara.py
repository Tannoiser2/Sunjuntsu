# Uso: python3.13 prepara.py <entrata.glb> <uscita.glb> <rotazione_gradi> <anteprima.png>
import bpy, bmesh, sys, math, mathutils
src, dst, rotz, png = sys.argv[-4], sys.argv[-3], float(sys.argv[-2]), sys.argv[-1]
FACCE = 45000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1: bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
for o in list(bpy.data.objects):
    if o != ob: bpy.data.objects.remove(o)
ob.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = ob.data
# rotazione per far guardare la figura verso -Y (il fronte nel gioco)
me.transform(mathutils.Matrix.Rotation(math.radians(rotz), 4, 'Z'))
vs = [v.co for v in me.vertices]
zmin = min(v.z for v in vs); zmax = max(v.z for v in vs); H = zmax - zmin
fondo = [v for v in vs if v.z < zmin + 0.01 * H]
cx = (max(v.x for v in fondo) + min(v.x for v in fondo)) / 2
cy = (max(v.y for v in fondo) + min(v.y for v in fondo)) / 2
R = max(math.hypot(v.x - cx, v.y - cy) for v in fondo)
# cima della base: prima fascia in cui nessun vertice arriva vicino al bordo
passo = 0.004 * H; top = zmin + 0.03 * H
z = zmin
while z < zmin + 0.4 * H:
    sl = [v for v in vs if z <= v.z < z + passo]
    if sl and max(math.hypot(v.x - cx, v.y - cy) for v in sl) < 0.86 * R:
        top = z; break
    z += passo
spess = top - zmin
# normalizzo: centro della base in 0, fondo a z=0, raggio dell'esagono = 1
k = 1.0 / R
me.transform(mathutils.Matrix.Scale(k, 4) @ mathutils.Matrix.Translation((-cx, -cy, -zmin)))
spess *= k; altezza = H * k
# tolgo la base vecchia (facce interamente sotto la cima della base)
bm = bmesh.new(); bm.from_mesh(me)
via = [f for f in bm.faces if all(v.co.z < spess - 0.002 for v in f.verts)]
bmesh.ops.delete(bm, geom=via, context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(me); bm.free()
# alleggerisco
if len(me.polygons) > FACCE:
    m = ob.modifiers.new('dec', 'DECIMATE'); m.ratio = FACCE / len(me.polygons)
    bpy.ops.object.modifier_apply(modifier='dec')
for im in bpy.data.images:
    if im.size[0] > 1024: im.scale(1024, 1024)
# materiali nuovi
def mat(nome, col, metal=0.0, rough=0.6):
    m = bpy.data.materials.new(nome); m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = col; b.inputs['Metallic'].default_value = metal; b.inputs['Roughness'].default_value = rough
    return m
if not me.materials:
    me.materials.append(mat('Figura', (0.55, 0.5, 0.45, 1)))
mb = mat('Base', (0.12, 0.11, 0.1, 1)); mf = mat('Freccia', (0.85, 0.65, 0.15, 1), 0.6, 0.35)
me.materials.append(mb); me.materials.append(mf)
ib = len(me.materials) - 2; iff = len(me.materials) - 1
bm = bmesh.new(); bm.from_mesh(me)
# esagono con lati piatti a +Y e -Y (vertici a 0, 60, ... gradi), un po' smussato
R1 = 0.97; s = max(spess, 0.06)
basso = [bm.verts.new((math.cos(math.radians(60 * i)), math.sin(math.radians(60 * i)), 0)) for i in range(6)]
alto = [bm.verts.new((R1 * math.cos(math.radians(60 * i)), R1 * math.sin(math.radians(60 * i)), s)) for i in range(6)]
nuove = [bm.faces.new(list(reversed(basso))), bm.faces.new(alto)]
for i in range(6):
    j = (i + 1) % 6
    nuove.append(bm.faces.new([basso[i], basso[j], alto[j], alto[i]]))
for f in nuove: f.material_index = ib
# freccia sul bordo frontale (-Y), in rilievo sopra la base
ap = R1 * math.sqrt(3) / 2
pts = [(-0.2, -ap + 0.06), (0.2, -ap + 0.06), (0.0, -ap - 0.0)]
pts = [(-0.22, -ap + 0.30), (0.22, -ap + 0.30), (0.0, -ap + 0.04)]
fb = [bm.verts.new((x, y, s + 0.004)) for x, y in pts]
ft = [bm.verts.new((x, y, s + 0.035)) for x, y in pts]
nf = [bm.faces.new(list(reversed(fb))), bm.faces.new(ft)]
for i in range(3):
    j = (i + 1) % 3
    nf.append(bm.faces.new([fb[i], fb[j], ft[j], ft[i]]))
for f in nf: f.material_index = iff
# freccia anche sulla faccia verticale frontale
y0 = -math.sqrt(3) / 2 * 0.985 - 0.012
tri = [(-0.16, s * 0.82), (0.16, s * 0.82), (0.0, s * 0.18)]
fv = [bm.verts.new((x, y0, z)) for x, z in tri]
f1 = bm.faces.new(fv); f1.material_index = iff
bmesh.ops.recalc_face_normals(bm, faces=nuove + nf)
bm.to_mesh(me); bm.free()
bpy.ops.object.shade_smooth()
ob.name = 'Miniatura'
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=82,
                          use_selection=False, export_apply=True)
# anteprima: vista frontale dall'alto (camera verso +Y)
sc = bpy.context.scene
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
cam.location = (0, -4.2, 1.0 + altezza * 0.45); cam.rotation_euler = (math.radians(75), 0, 0)
cam.data.lens = 50; sc.camera = cam
l = bpy.data.objects.new('sole', bpy.data.lights.new('sole', 'SUN')); l.data.energy = 4
l.rotation_euler = (math.radians(50), 0, math.radians(-30)); sc.collection.objects.link(l)
sc.world = bpy.data.worlds.new('w'); sc.world.color = (0.6, 0.6, 0.6)
sc.render.engine = 'CYCLES'; sc.cycles.samples = 12; sc.cycles.device = 'CPU'
sc.render.resolution_x = 360; sc.render.resolution_y = 420
sc.render.filepath = png
bpy.ops.render.render(write_still=True)
print('FATTO', dst.split('/')[-1], 'facce', len(me.polygons), 'spessore', round(s, 3), 'altezza', round(altezza, 2), 'R orig', round(R, 3))
