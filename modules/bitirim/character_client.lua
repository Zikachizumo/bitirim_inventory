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
    GAMEPLAY KAMERASINA DOKUNULMAZ — /cam yalnizca klonun sabit kamera onundeki
    YERLESIMINI ve backdrop objesini ayarlar.
]]

local Preview = exports[GetCurrentResourceName()]

-- Klon yerlesimi + backdrop (yalniz /cam ekrani icin yerel kopya; kaynak PreviewManager).
local cam_cfg = { dist = 3.70, side = -1.20, down = 0.00, bdist = 1.0, bz = 1.0, bhead = 0.0 }

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

-- KEY ISIK klavye ayari (index.tsx yollar): Numpad7/8 parlaklik, ok tuslari konum,
-- Numpad2/5 zoom. GAMEPLAY KAMERASI DEGISMEZ — sadece klon uzerindeki isik.
RegisterNUICallback('bitirim:lightTune', function(data, cb)
    cb(1)
    local a = type(data) == 'table' and data.action or nil
    if a then Preview:LightTune(a) end
end)

--[[
    /cam — KLON YERLESIMI + BACKDROP (onizleme acikken). GAMEPLAY KAMERASI DEGISMEZ.
    Begenince degerleri bana soyle, kalici yaparim.
      /cam dist <n>   klon kameranin ONUNDE kac metre (buyuk = uzak/kucuk)
      /cam side <n>   YATAY ofset (negatif = ekranda sola)
      /cam down <n>   DIKEY ofset (negatif = klon asagi; ayak-bas ortala)
      -- BACKDROP (koyu arka plan objesi):
      /cam bdist <n>  backdrop klonun ARKASINDA kac metre
      /cam bz <n>     backdrop dikey merkez
      /cam bhead <n>  backdrop aci ofseti
      /cam bmodel <model>  backdrop prop modelini degistir (orn: prop_container_01a)
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
    print(('^3[bitirim] cam dist=%.2f side=%.2f down=%.2f | backdrop dist=%.2f bz=%.2f bhead=%.1f (aktif:%s)^7')
        :format(cam_cfg.dist, cam_cfg.side, cam_cfg.down, cam_cfg.bdist, cam_cfg.bz, cam_cfg.bhead,
            tostring(Preview:IsPreviewActive())))
end, false)
