return {
    Build = function(ctx)
        ctx.Tab:Button({
            Title = "My game feature",
            Callback = function()
                ctx.Notify("It works!")
            end,
        })
    end,
}