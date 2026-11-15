# Carro in fiamme su due caselle: tolgo la base irregolare, giro il carro lungo la diagonale a 30 gradi
# e aggiungo una base di due esagoni regolari (raggio 0.95, centri a +-(0.75, 0.433)).
import bpy, bmesh, sys, math, mathutils
src, dst, png = sys.argv[-3], sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
me = ob.data
vs = [v.co for v in me.vertices]
zmin = min(v.z for v in vs); H = max(v.z for v in vs) - zmin
cx = (max(v.x for v in vs) + min(v.x for v in vs)) / 2; cy = (max(v.y for v in vs) + min(v.y for v in vs)) / 2
R = max(math.hypot(v.x - cx, v.y - cy) for v in vs if v.z < zmin + 0.01 * H)
top = zmin + 0.17
z = 99
while z < zmin + 0.4 * H:
    sl = [v for v in vs if z <= v.z < z + 0.004 * H]
    if sl and max(math.hypot(v.x - cx, v.y - cy) for v in sl) < 0.86 * R:
        top = z; break
    z += 0.004 * H
bm = bmesh.new(); bm.from_mesh(me)
via = [f for f in bm.faces if all(v.co.z < top + 0.004 for v in f.verts)]
bmesh.ops.delete(bm, geom=via, context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
# misuro il carro rimasto
xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]
mx = (max(xs) + min(xs)) / 2; my = (max(ys) + min(ys)) / 2
lung = max(max(xs) - min(xs), max(ys) - min(ys))
lungo_x = (max(xs) - min(xs)) >= (max(ys) - min(ys))
S = 2.5 / lung
SPESS = 0.08
rot = mathutils.Matrix.Rotation(math.radians(30 if lungo_x else -60), 4, 'Z')
for v in bm.verts:
    p = mathutils.Vector((v.co.x - mx, v.co.y - my, v.co.z - top)) * S
    v.co = rot @ p + mathutils.Vector((0, 0, SPESS))
# base di due esagoni
mat = bpy.data.materials.new('Base'); mat.use_nodes = True
b = mat.node_tree.nodes.get('Principled BSDF'); b.inputs['Base Color'].default_value = (0.24, 0.19, 0.14, 1); b.inputs['Roughness'].default_value = 0.9
me.materials.append(mat); ib = len(me.materials) - 1
for cxh, cyh in [(0.75, 0.433), (-0.75, -0.433)]:
    r = 0.95
    basso = [bm.verts.new((cxh + r * math.cos(math.radians(60 * i)), cyh + r * math.sin(math.radians(60 * i)), 0)) for i in range(6)]
    alto = [bm.verts.new((cxh + 0.93 * r * math.cos(math.radians(60 * i)), cyh + 0.93 * r * math.sin(math.radians(60 * i)), SPESS)) for i in range(6)]
    ff = [bm.faces.new(list(reversed(basso))), bm.faces.new(alto)]
    for i in range(6):
        j = (i + 1) % 6
        ff.append(bm.faces.new([basso[i], basso[j], alto[j], alto[i]]))
    for f in ff: f.material_index = ib
bm.to_mesh(me); bm.free()
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=82, export_apply=True)
sc = bpy.context.scene
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
cam.location = (0, -6, 4); cam.rotation_euler = (math.radians(58), 0, 0); sc.camera = cam
l = bpy.data.objects.new('sole', bpy.data.lights.new('sole', 'SUN')); l.data.energy = 4
l.rotation_euler = (math.radians(50), 0, math.radians(-30)); sc.collection.objects.link(l)
sc.world = bpy.data.worlds.new('w'); sc.world.color = (0.6, 0.6, 0.6)
sc.render.engine = 'CYCLES'; sc.cycles.samples = 8
sc.render.resolution_x = 480; sc.render.resolution_y = 300; sc.render.filepath = png
bpy.ops.render.render(write_still=True)
print('FATTO top', round(top - zmin, 3), 'lung', round(lung, 3), 'lungo_x', lungo_x)
