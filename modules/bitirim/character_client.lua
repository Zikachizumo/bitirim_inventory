--[[
    Bitirim — ENVANTER <-> PREVIEW MANAGER KOPRUSU
    ==============================================
    Canli 3B karakter onizlemesinin TUM mantigi artik yeniden kullanilabilir
    modulde: modules/bitirim/preview_manager.lua (exports API). Bu dosya YALNIZCA
    envanter NUI'sini o API'ye baglar; ikinci bir sistem/skin YOK.

        NUI 'bitirim:charScene'  {open}          -> CreatePreview / DestroyPreview
        NUI 'bitirim:charRotate' {mode,value}    -> RotatePreview
        NUI 'bitirim:charTune'   {action}        -> TuneScene (ok tuslari + Numpad1/2 dial)
        /cam ...                                 -> SetCamera (studio kadraj ince ayar)

    Mevcut NUI event isimleri/UI davranisi DEGISMEDI (index.tsx aynen calisir).
    STUDIO KAMERA MIMARISI: onizleme acikken PreviewManager kendi scripted kamerasini
    devreye alir (gameplay kamerasi ONEMSIZ hale gelir -> FP/TP/egim farketmez, arka
    plan her zaman kaplanir). /cam yalnizca bu studio kadrajinin ince ayarini yapar.
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

-- Studio kadraji (yalniz /cam yazdirmasi icin yerel kopya; kaynak PreviewManager).
local cam_cfg = { dist = 2.55, side = 0.0, height = 0.05, fov = 42.0, look = 0.30, backdist = 2.40 }

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

-- Klavye dial (index.tsx -> NUI): ok tuslari = kamera kadraj ofseti (yukari/asagi/
-- sag/sol), Numpad 1/2 = zoom. Klon SABIT konumda kalir, sadece kamera kadraji degisir.
RegisterNUICallback('bitirim:charTune', function(data, cb)
    cb(1)
    local action = type(data) == 'table' and data.action or nil
    if action then Preview:TuneScene(action) end
end)

--[[
    /cam — STUDIO KADRAJI ince ayar (onizleme acikken). GAMEPLAY KAMERASI ONEMSIZ
    (studio kamerasi devrede) — sadece bu kadraji degistirir. Ok tuslari + Numpad1/2
    ile de canli dial edilebilir (yukarida bitirim:charTune).
    Begenince degerleri bana soyle, kalici yaparim (preview_manager.lua cfg).
      /cam dist <n>      kamera klonun ONUNDE kac metre (buyuk = uzak/kucuk gorunur)
      /cam side <n>      kamera YATAY ofseti (negatif = ekranda sola)
      /cam height <n>    kamera dikey ofseti (gogus bonuna gore)
      /cam fov <n>       gorus acisi (kucuk = portre/dar, buyuk = genis)
      /cam look <n>      bakis hedefi gogusun kac metre ALTI
      /cam backdist <n>  siyah panel klonun kac metre ARKASINDA
]]
RegisterCommand('cam', function(_, args)
    local p, v = args[1], tonumber(args[2])
    if p and v and cam_cfg[p] ~= nil then
        cam_cfg[p] = v
        Preview:SetCamera({ [p] = v })
    end
    print(('^3[bitirim] cam dist=%.2f side=%.2f height=%.2f fov=%.1f look=%.2f backdist=%.2f (aktif:%s)^7')
        :format(cam_cfg.dist, cam_cfg.side, cam_cfg.height, cam_cfg.fov, cam_cfg.look, cam_cfg.backdist, tostring(Preview:IsPreviewActive())))
end, false)
