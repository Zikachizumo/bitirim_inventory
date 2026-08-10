--[[
    Bitirim — ENVANTER <-> PREVIEW MANAGER KOPRUSU
    ==============================================
    Canli 3B karakter onizlemesinin TUM mantigi artik yeniden kullanilabilir
    modulde: modules/bitirim/preview_manager.lua (exports API). Bu dosya YALNIZCA
    envanter NUI'sini o API'ye baglar; ikinci bir sistem/skin YOK.

        NUI 'bitirim:charScene'  {open}          -> CreatePreview / DestroyPreview
        NUI 'bitirim:charRotate' {mode,value}    -> RotatePreview
        /cam ...                                 -> SetCamera (klon yerlesimi ince ayar)

    Mevcut NUI event isimleri/UI davranisi DEGISMEDI (index.tsx aynen calisir).
    GAMEPLAY KAMERASINA DOKUNULMAZ — /cam yalnizca klonun sabit kamera onundeki
    YERLESIMINI ayarlar. (Backdrop objesi KALDIRILDI — sadece canli klon.)
]]

local Preview = exports[GetCurrentResourceName()]

-- ox_inventory ENVANTER ACILINCA ekrana SCREENBLUR uygular (native, tum oyunu
-- bulaniklastirir -> klon da BULANIK gorunur, NUI panelleri net kalir). Kullanici
-- bulanik istemiyor. Preview'in her-kare FadeOut(0.0) hilesi (0 sure) guvenilir
-- degil; en kesin cozum: ox'un blurIn'ini HIC cagirmamasi icin client.screenblur=false.
-- `client` = init.lua'da tanimli resource-global (local degil) -> buradan erisilebilir.
CreateThread(function()
    local t = 0
    while not client and t < 300 do Wait(10); t = t + 1 end
    if client then client.screenblur = false end
end)

-- Klon yerlesimi (yalniz /cam yazdirmasi icin yerel kopya; kaynak PreviewManager).
local cam_cfg = { dist = 3.35, side = -1.05, down = 0.51 }

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

-- Klavye ince ayar (index.tsx): ok tuslari=klon konumu, Numpad 1/2=zoom. KAMERA DEGISMEZ.
RegisterNUICallback('bitirim:charTune', function(data, cb)
    cb(1)
    local action = type(data) == 'table' and data.action or nil
    if action then Preview:TuneScene(action) end
end)

--[[
    /cam — KLON YERLESIMI ince ayar (onizleme acikken). GAMEPLAY KAMERASI DEGISMEZ.
    Begenince degerleri bana soyle, kalici yaparim. (Backdrop kaldirildi — sadece klon.)
      /cam dist <n>   klon kameranin ONUNDE kac metre (buyuk = uzak/kucuk)
      /cam side <n>   YATAY ofset (negatif = ekranda sola)
      /cam down <n>   DIKEY ofset (negatif = klon asagi; ayak-bas ortala)
]]
RegisterCommand('cam', function(_, args)
    local p, v = args[1], tonumber(args[2])
    if p and v and cam_cfg[p] ~= nil then
        cam_cfg[p] = v
        Preview:SetCamera({ [p] = v })
    end
    print(('^3[bitirim] cam dist=%.2f side=%.2f down=%.2f (aktif:%s)^7')
        :format(cam_cfg.dist, cam_cfg.side, cam_cfg.down, tostring(Preview:IsPreviewActive())))
end, false)
