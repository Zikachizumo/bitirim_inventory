--[[
    Bitirim — ENVANTER <-> PREVIEW MANAGER KOPRUSU
    ==============================================
    Canli 3B karakter onizlemesinin TUM mantigi artik yeniden kullanilabilir
    modulde: modules/bitirim/preview_manager.lua (exports API). Bu dosya YALNIZCA
    envanter NUI'sini o API'ye baglar; ikinci bir sistem/skin YOK.

        NUI 'bitirim:charScene'  {open}          -> CreatePreview / DestroyPreview
        NUI 'bitirim:charRotate' {mode,value}    -> RotatePreview
        /cam ...                                 -> SetCamera (kamera kompozisyonu)

    Mevcut NUI event isimleri/UI davranisi DEGISMEDI (index.tsx aynen calisir).
]]

local Preview = exports[GetCurrentResourceName()]

-- Kamera kompozisyonu (yalniz /cam ekrani icin yerel kopya; kaynak PreviewManager).
local cam_cfg = { dist = 3.55, height = 0.20, side = -0.98, fov = 44.0, lookz = -0.05, zoom = 1.0 }

------------------------------------------------------------------------------
-- NUI KOPRUSU (index.tsx bunlari yollar — isimler AYNEN korundu)
------------------------------------------------------------------------------
-- Karakter paneli gorundu/gizlendi -> onizlemeyi ac/kapat.
RegisterNUICallback('bitirim:charScene', function(data, cb)
    cb(1)
    if type(data) == 'table' and data.open then
        Preview:CreatePreview()
    else
        Preview:DestroyPreview()
    end
end)

-- Donme: sol/sag (heading) + fareyle surukle. ('top' kaldirildi — kamera sabit.)
RegisterNUICallback('bitirim:charRotate', function(data, cb)
    cb(1)
    local mode = type(data) == 'table' and data.mode or nil
    if not mode or mode == 'top' then return end
    Preview:RotatePreview(mode, type(data) == 'table' and data.value or nil)
end)

--[[
    /cam — CANLI KAMERA KOMPOZISYONU (onizleme acikken). Begenince degerleri
    bana soyle, kalici yaparim.
      /cam dist <n>   ped uzakligi (buyuk = kucuk/uzak)
      /cam side <n>   yatay: buyuk = ped daha SOLA
      /cam height <n> kamera yuksekligi
      /cam fov <n>    gorus acisi (35-45)
      /cam lookz <n>  bakis hedefi yuksekligi
      /cam zoom <n>   yakinlastirma (1=varsayilan, buyuk=yakin)
]]
RegisterCommand('cam', function(_, args)
    local p, v = args[1], tonumber(args[2])
    if p and v and cam_cfg[p] ~= nil then
        cam_cfg[p] = v
        Preview:SetCamera({ [p] = v })
    end
    print(('^3[bitirim] cam dist=%.2f side=%.2f height=%.2f fov=%.1f lookz=%.2f zoom=%.2f (aktif:%s)^7')
        :format(cam_cfg.dist, cam_cfg.side, cam_cfg.height, cam_cfg.fov, cam_cfg.lookz, cam_cfg.zoom,
            tostring(Preview:IsPreviewActive())))
end, false)
