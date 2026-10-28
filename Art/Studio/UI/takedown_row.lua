-- takedown_row.lua (2026-10-28, the takedown key made rebindable; owner: "Yes it should rebindable"): the Settings
-- panel's "Takedown" key row, in Edit only. SettingsUI builds no rows: it wires every child of
-- StarterGui.Uis.Settings.MainFrame.Container by its Tab and Kind attributes, and the rows are authored instances
-- (as Aim and Compass were added, 2026-10-17 / 2026-10-18). So the row is a clone of the existing Aim (Guns) key row
-- (the same template and art; no new assets), named Takedown (the Keys name SettingsUI reads), titled "Takedown", after
-- Aim (LayoutOrder 150; Aim is 145). It carries the attribute KeyNAdd = true, and only such a row is ever removed.
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @Art/Studio/UI/takedown_row.lua
-- MODE: "add" (returns "added", or "already there") | "remove" (copy this file, set MODE there; returns "removed n").
-- Both refuse while Play runs. Places: Ye and Foundry Yard (the Tutorial has no rebindable takedown: left alone).
local MODE = "add"
if game:GetService("RunService"):IsRunning() then return "REFUSED: " .. MODE .. " in Edit, not while Play runs" end
local Uis = game:GetService("StarterGui"):FindFirstChild("Uis")
local Settings = Uis and Uis:FindFirstChild("Settings")
local Main = Settings and Settings:FindFirstChild("MainFrame")
local Container = Main and Main:FindFirstChild("Container")
if not Container then return "REFUSED: no StarterGui.Uis.Settings.MainFrame.Container" end
if MODE == "remove" then
	local N = 0
	for _, C in ipairs(Container:GetChildren()) do
		if C.Name == "Takedown" and C:GetAttribute("KeyNAdd") == true then C:Destroy() N += 1 end
	end
	return "removed " .. N
end
if MODE ~= "add" then return "REFUSED: unknown MODE " .. tostring(MODE) end
local Aim = Container:FindFirstChild("Aim")
if not (Aim and Aim:GetAttribute("Kind") == "Key" and Aim:GetAttribute("Tab") == "Keybinds") then
	return "REFUSED: no Aim key row to copy"
end
-- A row parented into the Container in Edit came out shorter than its template (measured 2026-10-28: Size Y 0.049 for
-- Aim's 0.0913, the same thing the 2026-10-18 entry fixed for Combat Log and Aim), so the Size is set again after
-- parenting, and a re-run puts a short KeyNAdd row back to Aim's size.
local Have = Container:FindFirstChild("Takedown")
if Have then
	if Have:GetAttribute("KeyNAdd") == true and Have.Size ~= Aim.Size then
		Have.Size = Aim.Size
		return "already there; resized to " .. tostring(Have.Size)
	end
	return "already there"
end
local Title = Aim:FindFirstChild("Title")
local Head = Aim:FindFirstChild("Controls") and Aim.Controls:FindFirstChild("Bind") and Aim.Controls.Bind:FindFirstChild("Head")
if not (Title and Title:IsA("TextLabel") and Head) then return "REFUSED: the Aim row has no Title or Controls.Bind.Head" end
local Row = Aim:Clone()
Row.Name = "Takedown"
Row.LayoutOrder = 150
Row.Title.Text = "Takedown"
Row:SetAttribute("KeyNAdd", true)
Row.Parent = Container
Row.Size = Aim.Size
return "added " .. tostring(Row.Size)
