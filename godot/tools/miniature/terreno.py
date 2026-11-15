# Uso: python3.13 terreno.py <entrata.glb> <uscita.glb> <anteprima.png> <facce>
import bpy, sys, math, mathutils
src, dst, png, FACCE = sys.argv[-4], sys.argv[-3], sys.argv[-2], int(sys.argv[-1])
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
if len(me.polygons) > FACCE:
    m = ob.modifiers.new('dec', 'DECIMATE'); m.ratio = FACCE / len(me.polygons)
    bpy.ops.object.modifier_apply(modifier='dec')
vs = [v.co for v in me.vertices]
mn = [min(v[i] for v in vs) for i in range(3)]; mx = [max(v[i] for v in vs) for i in range(3)]
me.transform(mathutils.Matrix.Translation((-(mn[0]+mx[0])/2, -(mn[1]+mx[1])/2, -mn[2])))
for im in bpy.data.images:
    if im.size[0] > 1024: im.scale(1024, 1024)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=82, export_apply=True)
sc = bpy.context.scene
for nome, loc, rot in [('a', (0, -3.2, 1.6), (70, 0, 0))]:
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
    cam.location = loc; cam.rotation_euler = tuple(math.radians(r) for r in rot); sc.camera = cam
l = bpy.data.objects.new('sole', bpy.data.lights.new('sole', 'SUN')); l.data.energy = 4
l.rotation_euler = (math.radians(50), 0, math.radians(-30)); sc.collection.objects.link(l)
sc.world = bpy.data.worlds.new('w'); sc.world.color = (0.6, 0.6, 0.6)
sc.render.engine = 'CYCLES'; sc.cycles.samples = 8
sc.render.resolution_x = 360; sc.render.resolution_y = 300; sc.render.filepath = png
bpy.ops.render.render(write_still=True)
print('FATTO', dst, 'dim', [round(mx[i]-mn[i], 3) for i in range(3)], 'facce', len(me.polygons))
