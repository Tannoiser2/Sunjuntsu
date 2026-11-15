# Torii su tre caselle: colonne sulle caselle esterne, passaggio libero al centro.
import bpy, bmesh, sys, math, mathutils
src, dst, png = sys.argv[-3], sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
me = ob.data
vs = [v.co for v in me.vertices]
zmin = min(v.z for v in vs); H = max(v.z for v in vs) - zmin
# cima della base: prima fascia in cui i vertici non arrivano più al bordo
R = max(math.hypot(v.x, v.y) for v in vs if v.z < zmin + 0.01 * H)
top = zmin + 0.03 * H
z = zmin
while z < zmin + 0.3 * H:
    sl = [v for v in vs if z <= v.z < z + 0.004 * H]
    if sl and max(math.hypot(v.x, v.y) for v in sl) < 0.86 * R:
        top = z; break
    z += 0.004 * H
bm = bmesh.new(); bm.from_mesh(me)
via = [f for f in bm.faces if all(v.co.z < top + 0.004 for v in f.verts)]
bmesh.ops.delete(bm, geom=via, context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
# allargo: le metà esterne si spostano, la parte centrale (travi, corda) si stira
S = 1.4; SH = 0.787; M = 0.3
for v in bm.verts:
    x = v.co.x
    if abs(x) > M:
        x = x + math.copysign(SH, x)
    else:
        x = x * (M + SH) / M
    v.co = mathutils.Vector((x * S, v.co.y * S, (v.co.z - top) * S))
bm.to_mesh(me); bm.free()
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=82, export_apply=True)
sc = bpy.context.scene
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
cam.location = (0, -7, 3); cam.rotation_euler = (math.radians(72), 0, 0); sc.camera = cam
l = bpy.data.objects.new('sole', bpy.data.lights.new('sole', 'SUN')); l.data.energy = 4
l.rotation_euler = (math.radians(50), 0, math.radians(-30)); sc.collection.objects.link(l)
sc.world = bpy.data.worlds.new('w'); sc.world.color = (0.6, 0.6, 0.6)
sc.render.engine = 'CYCLES'; sc.cycles.samples = 8
sc.render.resolution_x = 480; sc.render.resolution_y = 300; sc.render.filepath = png
bpy.ops.render.render(write_still=True)
print('FATTO top', round(top, 3), 'R', round(R, 3))
