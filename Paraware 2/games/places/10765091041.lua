return {
    Name = "Game tools",
    Build = function(ctx)
        assert(ctx.PlaceId == 10765091041, "This module is only for place 10765091041")
        ctx.Tab:Paragraph({
            Title = "Game detected",
            Desc = "Paraware loaded this game's dedicated module.\nPlace: " .. ctx.PlaceId .. "\nUniverse: " .. ctx.UniverseId,
        })
        ctx.Tab:Button({
            Title = "Game detected",
            Desc = "Check that this game's module is connected.",
            Icon = "gamepad-2",
            Callback = function()
                ctx.Notify("Paraware is connected to place " .. ctx.PlaceId .. ". The dedicated game tab is loaded.")
            end,
        })
    end,
}
