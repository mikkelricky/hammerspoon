--- === YabaiGridSpaces ===
---
--- Yabai Grid Spaces spoon.
---
--- Download: <http://github.com/mikkelricky/hammerspoon/raw/main/Spoons/YabaiGridSpaces.spoon.zip>

local NORTH <const> = "north"
local EAST <const> = "east"
local SOUTH <const> = "south"
local WEST <const> = "west"

local screen = require("hs.screen")
local canvas = require("hs.canvas")

local debug = function(v)
  hs.alert(hs.json.encode(v, true))
end

local YabaiGridSpaces = {
  -- Metadata
  name = "YabaiGridSpaces",
  version = "1.0",
  author = "Mikkel Ricky <mikkel@mikkelricky.dk>",
  homepage = "http://github.com/mikkelricky/hammerspoon",
  license = "MIT - https://opensource.org/licenses/MIT",
}

-- GridSpaces configuration
local yabaiPath = "/usr/local/bin/yabai"
local numberOfColumns = 3
local gridDisplayTimeout = 0.75
local gridScale = 0.05
local wrapAround = false

--- YabaiGridSpaces:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for YabaiGridSpaces
---
--- Parameters:
---  * config - A table containing config:
---   * reloadConfiguration - This will cause the configuration to be reloaded
function YabaiGridSpaces:applyConfig(config)
  yabaiPath = config.yabaiPath or "/usr/local/bin/yabai"
  numberOfColumns = config.numberOfColumns or 3
  gridDisplayTimeout = config.gridDisplayTimeout or 0.75
  gridScale = config.gridScale or 0.05
  wrapAround = config.wrapAround or false

  return self
end

-- Apply default config.
YabaiGridSpaces:applyConfig({})

--------------------------------------------------------------------------------

local screenFrame = screen.mainScreen():fullFrame()

local getSpaces = function()
  local s, status, _, _ = hs.execute(yabaiPath .. " --message query --spaces")
  local spaces = {}
  if status then
    -- [
    -- …,
    -- {
    --     "id":7,
    --     "uuid":"B7359B82-B974-4BAB-B351-50B45704C199",
    --     "index":5,
    --     "label":"",
    --     "type":"float",
    --     "display":1,
    --     "windows":[1176, 10128, 2285],
    --     "first-window":0,
    --     "last-window":0,
    --     "has-focus":false,
    --     "is-visible":false,
    --     "is-native-fullscreen":false
    -- },
    -- …
    -- ]
    local data = hs.json.decode(s)
    spaces.spaces = {}
    spaces.cols = numberOfColumns
    spaces.rows = math.ceil(#data / numberOfColumns)
    spaces.hasFullScreenSpace = false
    spaces.firstFullScreenIndex = -1

    for index, space in ipairs(data) do
      if space["is-native-fullscreen"] then
        spaces.hasFullScreenSpace = true
        if spaces.firstFullScreenIndex < 0 then
          spaces.firstFullScreenIndex = index - 1
        end
      end
      space.index = space.index - 1
      space.isCurrent = space["has-focus"]
      space.isFullScreen = space["is-native-fullscreen"]
      space.col = space.index % numberOfColumns
      space.row = math.floor(space.index / numberOfColumns)
      table.insert(spaces.spaces, space)
      if space.isCurrent then
        spaces.currentSpace = space
      end
    end
  end

  return spaces
end

-- https://github.com/asmagill/hammerspoon/wiki/hs.canvas.examples
function showGrid(grid, params)
  params = params or {}

  local currentSpace = params.currentSpace or grid.currentSpace

  local cellWidth = screenFrame.w * gridScale
  local cellHeight = screenFrame.h * gridScale
  local gap = 10

  local width = cellWidth * grid.cols + (grid.cols + 1) * gap
  local height = cellHeight * grid.rows + (grid.rows + 1) * gap

  if grid.firstFullScreenIndex > 0 then
    height = height + gap
  end

  local alpha = 1

  local a = canvas.new({
    x = (screenFrame.w - width) / 2,
    y = (screenFrame.h - height) / 2,
    w = width,
    h = height,
  })

  a:appendElements({
    type = "rectangle",
    roundedRectRadii = {
      xRadius = gap,
      yRadius = gap,
    },
    fillColor = {
      white = 0.5,
      alpha = alpha,
    },
  })

  if grid.firstFullScreenIndex > 0 then
    local y = gap + (gap + cellHeight) * math.floor(grid.firstFullScreenIndex / grid.cols)
    a:appendElements({
      type = "segments",
      coordinates = {
        { x = gap, y = y },
        { x = width - gap, y = y },
      },

      closed = false,
      strokeColor = {
        white = 0.5,
        alpha = alpha,
      },
    })
  end

  for _, space in ipairs(grid.spaces) do
    if space.index < #grid.spaces then
      local y = gap + (gap + cellHeight) * space.row
      if space.isFullScreen then
        y = y + gap
      end

      local isCurrent = space == currentSpace
      a:appendElements(
        {
          type = "rectangle",
          frame = {
            x = gap + (gap + cellWidth) * space.col,
            y = y,
            w = cellWidth,
            h = cellHeight,
          },
          -- http://lua-users.org/wiki/TernaryOperator
          fillColor = isCurrent and { white = 0.75, alpha = alpha } or { white = 0.5, alpha = alpha },
        }
        -- {
        --   frame = {
        --     x = gap+(gap+ cellWidth)*space.col,
        --     y = y,
        --     w = cellWidth,
        --     h = cellHeight,
        --   },
        --   text = hs.styledtext.new(space.index+1, {
        --                              font = { name = ".AppleSystemUIFont", size = cellHeight/2 },
        --                              paragraphStyle = { alignment = "center" }
        --   }),
        --   type = "text",
        -- }
      )
    end
  end

  a:show()
  a:delete(gridDisplayTimeout)
end

local function spacesNavigate(direction)
  local spaces = getSpaces()
  if spaces then
    local currentSpace = spaces.currentSpace
    if currentSpace then
      local currentRow = currentSpace.row
      local currentColumn = currentSpace.col
      local targetRow = currentRow
      local targetColumn = currentColumn

      if direction == NORTH then
        targetRow = currentRow - 1
      elseif direction == SOUTH then
        targetRow = currentRow + 1
      elseif direction == EAST then
        targetColumn = currentColumn + 1
      elseif direction == WEST then
        targetColumn = currentColumn - 1
      end

      if not wrapAround then
        if targetColumn < 0 or targetColumn >= spaces.cols or targetRow < 0 or targetColumn >= spaces.rows then
          return
        end
      end

      local targetSpace = targetColumn + targetRow * spaces.cols + 1

      if targetSpace > 0 and targetSpace <= #spaces.spaces then
        local _, status, _, _ = hs.execute(yabaiPath .. " --message space --focus " .. targetSpace)
        if status then
          showGrid(spaces, { currentSpace = spaces.spaces[targetSpace] })
        end
      end
    end
  end
end

--- YabaiGridSpaces:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for YabaiGridSpaces
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * navigateNorth -
---   * navigateEast -
---   * navigateSouth -
---   * navigateWest -
function YabaiGridSpaces:bindHotKeys(mapping)
  local spec = {
    navigateNorth = hs.fnutils.partial(function()
      spacesNavigate(NORTH)
    end, self),
    navigateEast = hs.fnutils.partial(function()
      spacesNavigate(EAST)
    end, self),
    navigateSouth = hs.fnutils.partial(function()
      spacesNavigate(SOUTH)
    end, self),
    navigateWest = hs.fnutils.partial(function()
      spacesNavigate(WEST)
    end, self),
  }
  hs.spoons.bindHotkeysToSpec(spec, mapping)

  return self
end

--- YabaiGridSpaces:start()
--- Method
--- Start YabaiGridSpaces
---
--- Parameters:
---  * None
function YabaiGridSpaces:start()
  showGrid(getSpaces())

  -- TODO Check that yabai can be run
  -- TODO Load configuration from file?
  return self
end

return YabaiGridSpaces
