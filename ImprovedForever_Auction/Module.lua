-- Improved Forever: Auction. The auction house's prices kept over time
-- (Auction.lua), our own auction window over the game's (AuctionBuy.lua:
-- Buy, Sell, Auctions, Tasks) and the tasks: what to buy, craft or sell
-- (Tasks.lua), tracked in the objective tracker, added from the profession
-- window (TaskCraft.lua), done at vendors (VendorTasks.lua) and the auction
-- house (AuctionTasks.lua). Set up in its tab (AuctionEditor.lua).
local IF = ImprovedForever

IF.AddModule({ key = "auction", label = "Auction", icon = IF.TEX .. "ic_mod_auction", addon = ... })

-- The auction window as a scene (AuctionScene.lua) only with the Immersion
-- module (loaded first: an optional dependency) and its "Auction house
-- scene" switch on; else its classic look (the *Classic.lua files). Read
-- from the saved table itself: IF.db comes at login, after the files load.
local saved = rawget(_G, "ImprovedForeverDB")
IF.auctionScene = IF.Interface ~= nil
    and not (type(saved) == "table" and type(saved.interface) == "table" and saved.interface.auctionScene == false)

-- /if scan: scan the auction house's prices (it must be open)
IF.AddCommand("scan", function() IF.Auction.Scan() end, ": scan the auction house's prices")
-- /if upgrade: why the Buy tab's picked item is an upgrade or not
IF.AddCommand("upgrade", function() IF.AuctionBuy.Explain() end, ": why the picked item is an upgrade")

-- /if tasks: the tasks, their recipes' tracking, the tracker's Professions section
IF.AddCommand("tasks", function() IF.Tasks.Report() end, ": the tasks and their tracking")
-- /if addprobe: why the profession window's "Hold to Add Task" shows or not
IF.AddCommand("addprobe", function()
    -- (again 3 s and 6 s later: back on the recipe list by then, the chat
    -- no longer holding the pad)
    IF.TaskCraft.Probe()
    C_Timer.After(3, IF.TaskCraft.Probe)
    C_Timer.After(6, IF.TaskCraft.Probe)
end)
