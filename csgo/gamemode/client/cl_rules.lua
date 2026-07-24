local blockedBinds = {
    ["+menu"] = true,
    ["+menu_context"] = true
}

local function IsExemptSuperAdmin()
    local ply = LocalPlayer()
    return IsValid(ply) and ply:IsSuperAdmin()
end

hook.Add("OnSpawnMenuOpen", "CSGO.BlockSpawnMenu", function()
    if IsExemptSuperAdmin() then return end
    return false
end)

hook.Add("OnContextMenuOpen", "CSGO.BlockContextMenu", function()
    if IsExemptSuperAdmin() then return end
    return false
end)

hook.Add("PlayerBindPress", "CSGO.BlockMenuBinds", function(ply, bind)
    if IsValid(ply) and ply:IsSuperAdmin() then return end

    bind = string.lower(string.Trim(bind))
    if blockedBinds[bind] or string.find(bind, "+menu", 1, true) or string.find(bind, "gm_show", 1, true) then
        return true
    end
end)
