-- Lua Lamp Canvas View Component
-- Adapts the Hello World stage canvas into a first-class RootView node view.

local View = require "core.view"
local canvas = require "src.canvas"

---@class CanvasView : core.view
local CanvasView = View:extend()

function CanvasView:new()
  CanvasView.super.new(self)
end

function CanvasView:get_name()
  return "Hello World"
end

function CanvasView:draw()
  canvas.draw(self.size.x, self.size.y)
end

function CanvasView:on_mouse_moved(px, py)
  canvas.on_mouse_moved(px, py)
end

function CanvasView:on_mouse_pressed(button, px, py)
  local core = require "core"
  return canvas.on_mouse_pressed(button, px, py, core)
end

return CanvasView
