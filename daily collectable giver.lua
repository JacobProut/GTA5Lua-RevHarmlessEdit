DCTAB:gui.get_tab("Daily Collectable Giver")



DCTAB:add_imgui(function()
    getAllPlayers()
    collectAllDailyItems()
    giveCollectiblesToPlayer()
    createMenu()
)



-- Function to collect all daily collectibles
function collectAllDailyItems()
    local collectibles = {} -- Array to store all collectibles

    -- Assuming YimMenu has a function to get daily collectibles
    -- Example function, replace with actual YimMenu function
    collectibles = getAllDailyCollectibles()

    return collectibles
end

-- Function to give collectibles to other players
function giveCollectiblesToPlayer(playerId, collectibles)
    for _, collectible in ipairs(collectibles) do
        -- Assuming YimMenu has a function to give collectibles
        -- Example function, replace with actual YimMenu function
        giveCollectibleToPlayer(playerId, collectible)
    end
end

-- Function to get a list of all players
function getAllPlayers()
    local players = {}

    -- Assuming YimMenu has a function to get all players
    -- Example function, replace with actual YimMenu function
    players = getPlayersList()

    return players
end

-- Function to create and show the menu
function createMenu()
    -- Create the menu
    local menu = yimMenu.createMenu("Give Daily Collectibles")

    -- Get the list of players
    local players = getAllPlayers()

    -- Add a submenu for each player
    for _, player in ipairs(players) do
        menu:addItem({
            label = player.name,
            action = function()
                local dailyItems = collectAllDailyItems()
                giveCollectiblesToPlayer(player.id, dailyItems)
                yimMenu.showNotification("Gave all daily collectibles to " .. player.name)
            end
        })
    end

    -- Show the menu
    yimMenu.showMenu(menu)
end

-- Run the script by creating the menu
createMenu()