--[[
    Bitirim — ENVANTER <-> PREVIEW MANAGER KOPRUSU
    ==============================================
    Canli 3B karakter onizlemesinin TUM mantigi artik yeniden kullanilabilir
    modulde: modules/bitirim/preview_manager.lua (exports API). Bu dosya YALNIZCA
    envanter NUI'sini o API'ye baglar; ikinci bir sistem/skin YOK.

        NUI 'bitirim:charScene'  {open}          -> CreatePreview / DestroyPreview
        NUI 'bitirim:charRotate' {mode,value}    -> RotatePreview
        /cam ...                                 -> SetCamera (klon yerlesimi + backdrop)

    Mevcut NUI event isimleri/UI davranisi DEGISMEDI (index.tsx aynen calisir).
    GAMEPLAY KAMERASINA DOKUNULMAZ — scripted preview kamera SADECE render'i devralir;
    /cam onizleme kamerasi kompozisyonunu + backdrop + isik ayarlar.
]]

local Preview = exports[GetCurrentResourceName()]

-- Preview kamera + backdrop + isik (yalniz /cam ekrani icin yerel kopya; kaynak PreviewManager).
local cam_cfg = { dist = 3.55, height = 0.20, side = -0.98, fov = 44.0, lookz = -0.05, zoom = 1.0,
                  bdist = 1.6, bz = 1.0, bhead = 90.0, keyint = 2.2 }

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
    /cam — PREVIEW KAMERA + BACKDROP + ISIK. GAMEPLAY KAMERASI DEGISMEZ.
    NOT: envanter acikken chat acilmaz; bu komut envanter KAPALIYKEN degil, ancak
    gelistirme/test icindir. Begenince degerleri bana soyle, kalici yaparim.
      /cam dist <n>    klon uzakligi (buyuk = kucuk/uzak)
      /cam height <n>  kamera yuksekligi
      /cam side <n>    yatay: buyuk = ped daha SOLA
      /cam fov <n>     gorus acisi (35-50)
      /cam lookz <n>   bakis hedefi yuksekligi
      /cam zoom <n>    yakinlastirma (1=varsayilan)
      -- BACKDROP + ISIK (koyu void arka plan):
      /cam bdist <n>   backdrop klonun ARKASINDA kac metre
      /cam bz <n>      backdrop dikey merkez
      /cam bhead <n>   backdrop aci ofseti
      /cam keyint <n>  klon isik siddeti (koyu kalirsa artir)
      /cam bmodel <m>  backdrop prop modeli
]]
RegisterCommand('cam', function(_, args)
    local p, v = args[1], tonumber(args[2])
    if p == 'bmodel' and args[2] then
        Preview:SetCamera({ bmodel = args[2] })
        print('^3[bitirim] backdrop model = ' .. args[2] .. '^7')
        return
    elseif p and v and cam_cfg[p] ~= nil then
        cam_cfg[p] = v
        Preview:SetCamera({ [p] = v })
    end
    print(('^3[bitirim] cam dist=%.2f height=%.2f side=%.2f fov=%.1f lookz=%.2f | bdist=%.2f bz=%.2f bhead=%.1f keyint=%.2f (aktif:%s)^7')
        :format(cam_cfg.dist, cam_cfg.height, cam_cfg.side, cam_cfg.fov, cam_cfg.lookz,
            cam_cfg.bdist, cam_cfg.bz, cam_cfg.bhead, cam_cfg.keyint, tostring(Preview:IsPreviewActive())))
end, false)
