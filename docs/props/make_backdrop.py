import bpy, addon_utils, sys, os, math, struct
import numpy as np

def write_solid_dds(path, w, h, r, g, b, a=255):
    """Sikistirilmamis 32bpp (A8R8G8B8) DDS yaz — duz renk icin ideal, GTA destekler."""
    DDSD = 0x1|0x2|0x4|0x1000|0x8  # CAPS,HEIGHT,WIDTH,PIXELFORMAT,PITCH
    pitch = w*4
    hdr = b'DDS '
    hdr += struct.pack('<7I', 124, DDSD, h, w, pitch, 0, 0)   # size..mipcount
    hdr += b'\x00'*44                                          # reserved1[11]
    # ddspf: size,flags(RGB|ALPHAPIXELS),fourCC,bitcount,R,G,B,A masks
    hdr += struct.pack('<8I', 32, 0x41, 0, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
    hdr += struct.pack('<5I', 0x1000, 0, 0, 0, 0)             # caps..reserved2
    row = bytes([b, g, r, a]) * w                             # BGRA
    with open(path, 'wb') as f:
        f.write(hdr)
        for _ in range(h):
            f.write(row)

argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
OUT_DIR   = argv[0] if len(argv) > 0 else os.getcwd()
MODEL     = argv[1] if len(argv) > 1 else "bitirim_backdrop01"
SHADER_IX = int(argv[2]) if len(argv) > 2 else 39   # emissive_alpha.sps
SIZE      = float(argv[3]) if len(argv) > 3 else 20.0  # kare panel kenar (m). Buyuk =
                                                       # kamera arkasinda TAM EKRANI kaplar.
# %100 SIYAH (gri ton yok) — kullanici istegi
R, G, B = 0.0, 0.0, 0.0

# --- Sollumz etkinlestir ---
for m in addon_utils.modules():
    if 'sollumz' in m.__name__.lower():
        addon_utils.enable(m.__name__, default_set=True, persistent=True)

def log(*a): print("[MB]", *a)

# --- Sahneyi temizle ---
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
    for it in list(blk):
        try: blk.remove(it)
        except Exception: pass

# --- kare panel, dik (SIZE m; buyuk -> tam ekran backdrop) ---
bpy.ops.mesh.primitive_plane_add(size=SIZE, location=(0,0,0))
plane = bpy.context.active_object
plane.name = MODEL
plane.rotation_euler[0] = math.radians(90)  # dik: yuzu -Y'ye baksin
bpy.context.view_layer.objects.active = plane
plane.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# --- UV ---
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.unwrap(method='ANGLE_BASED', margin=0.001)
bpy.ops.object.mode_set(mode='OBJECT')

# --- Koyu doku: DDS olarak yaz (Sollumz embed DDS ister) + Blender'a yukle ---
dds_path = os.path.join(OUT_DIR, MODEL + "_tex.dds")
write_solid_dds(dds_path, 128, 128, int(R*255), int(G*255), int(B*255), 255)
log("dds written", dds_path, os.path.getsize(dds_path), "bytes")
try:
    img = bpy.data.images.load(dds_path, check_existing=True)
    log("dds loaded into blender", img.name, tuple(img.size))
except Exception as e:
    img = bpy.data.images.new(MODEL + "_tex", 128, 128, alpha=True)
    img.filepath = dds_path
    log("dds load failed, filepath set instead", repr(e))
img.colorspace_settings.name = 'sRGB'

# --- Sollumz shader materyali ---
bpy.context.view_layer.objects.active = plane
plane.select_set(True)
bpy.ops.sollumz.createshadermaterial(shader_index=SHADER_IX)
mat = plane.active_material
log("material", mat.name if mat else None)

# DiffuseSampler image texture node'unu bul ve dokuyu ata
tex_nodes = [n for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE']
log("tex image nodes", [n.name for n in tex_nodes])
for n in tex_nodes:
    if 'diffuse' in n.name.lower() or n.name.lower().startswith('diffusesampler') or len(tex_nodes) == 1:
        n.image = img
        # Sollumz: dokuyi ydr'ye GOM (texture_properties.embedded) + isim
        if getattr(n, 'texture_properties', None) is not None:
            n.texture_properties.embedded = True
            log("texture_properties.embedded=True on", n.name)
        try:
            n.sollumz_texture_name = MODEL + "_tex"
        except Exception as e:
            log("tex name set fail", repr(e))

# --- Drawable'a cevir ---
bpy.context.view_layer.objects.active = plane
plane.select_set(True)
bpy.ops.sollumz.converttodrawable()
# convert sonrasi aktif obje Drawable olabilir; ismi garantiye al
draw_obj = bpy.context.active_object or plane
# Drawable objesini bul
for o in bpy.data.objects:
    if getattr(o, 'sollum_type', '') and 'drawable' in str(o.sollum_type).lower() and 'model' not in str(o.sollum_type).lower():
        draw_obj = o
draw_obj.name = MODEL
log("drawable obj", draw_obj.name, getattr(draw_obj,'sollum_type',''))

# --- Export .ydr (NATIVE/GEN8) ---
bpy.ops.object.select_all(action='DESELECT')
draw_obj.select_set(True)
bpy.context.view_layer.objects.active = draw_obj
os.makedirs(OUT_DIR, exist_ok=True)
res = bpy.ops.sollumz.export_assets(
    directory=OUT_DIR,
    target_formats={'NATIVE'},
    target_versions={'GEN8'},
    limit_to_selected=True,
    apply_transforms=True,
    use_custom_settings=True,
)
log("export result", res)
for f in os.listdir(OUT_DIR):
    if f.lower().endswith('.ydr') or f.lower().endswith('.ytd'):
        log("OUTPUT", f, os.path.getsize(os.path.join(OUT_DIR, f)), "bytes")
log("DONE")
