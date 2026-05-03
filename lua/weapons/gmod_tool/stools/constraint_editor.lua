local mode = TOOL.Mode
ConstraintEditor.Mode = mode

--[[
if SERVER then

	local flags = bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED )

	-- Create server console variables here.

	flags = nil
]]

if CLIENT then

	TOOL.Category	= "Constraints"
	TOOL.Name		= "Constraint Editor"

	TOOL.Information = {
		{ name = "left0", stage = 0 },
		{ name = "left", stage = 1 },
		{ name = "left", stage = 2 },
		{ name = "shift", icon2 = "icon16/keyboard.png", icon = "icon16/arrow_up.png" },
		{ name = "right", stage = 1 },
		{ name = "right", stage = 2 },
		{ name = "reload1", stage = 1 },
		{ name = "reload2", stage = 2 },
		--{ name = "reload1_use", stage = 1 },
		--{ name = "reload2_use", stage = 2 },
	}

	TOOL.ClientConVar = {
		["hud_show_text"]		= 1,
		["hud_show_lines"]		= 1,
		["hud_show_halos"]		= 1,
		["hud_beam_width_min"]	= 1,
		["transfer_mode"]		= 1
	}

	local t = "tool." .. mode .. "."
	local function l( ... )
		local a = { ... }
		if #a == 2 then table.insert( a, 1, t ) elseif #a < 2 then return end
		language.Add( a[1] .. a[2], a[3] )
	end

	l( "listname", "Constraint Editor" )
	l( "name", TOOL.Name )
	l( "desc", "Edit any constraint." )
	l( "0" )
	l( "left0", "SELECT an entity to see its constraints" )
	l( "left", "SELECT constraints and/or other entities" )
	l( "shift", "Press " .. ( input.LookupBinding( "+speed" ) or "Sprint" ) .. " to not clear selection on left click" )
	l( "right", "DELETE the constraint you're facing, or CLEAR your entity selection" )
	l( "reload1", "TRANSFER all constraints from your entity selection to the entity you're looking at" )
	l( "reload2", "TRANSFER selected constraint(s) to the entity you're looking at" )
	--l( "reload1_use", "Transfer all constraints from the edited entity to the one you're looking at" )
	--l( "reload2_use", "Transfer selected constraint from the edited entity to the one you're looking at" )

	t, l = nil, nil

end


function TOOL:LeftClick( trace )

	if SERVER then
		ConstraintEditor.TryCleanupTables()
		ConstraintEditor.NetSend(
			ConstraintEditor.netTags.TOOLGUN_LEFT_CLICK, self:GetOwner(),
			{ trace.Entity }
		)
	end

	return true

end


function TOOL:RightClick( trace )

	if SERVER then
		ConstraintEditor.TryCleanupTables()
		ConstraintEditor.NetSend(
			ConstraintEditor.netTags.TOOLGUN_RIGHT_CLICK, self:GetOwner()
		)
	end

	return true

end


function TOOL:Reload()

	if SERVER then
		ConstraintEditor.TryCleanupTables()
		ConstraintEditor.NetSend(
			ConstraintEditor.netTags.TOOLGUN_MIDDLE_CLICK, self:GetOwner()
		)
	end

	return true

end


ConstraintEditor.HandleNetRequests( mode )


local conVars = CLIENT and TOOL:BuildConVarList() or nil

--bind f5 "lua_run_cl print(Entity(1):GetTool('constraint_editor'):RebuildControlPanel())"
function TOOL.BuildCPanel( cPanel )

	local t = "tool." .. mode .. "."
	local function l( ... )
		local a = { ... }
		if #a == 1 then table.insert( a, 1, t )
		elseif #a < 1 then return end
		return language.GetPhrase( a[1] .. a[2] )
	end

	local hcol	= cPanel:GetSkin().Colours.Tree.Hover
	local bgcol	= cPanel:GetSkin().Colours.Category.LineAlt.Button

	cPanel:ToolPresets( mode, conVars )

	cPanel:Help( l( "desc" ) )

	local settingsDForm = vgui.Create( "DForm", cPanel )
	cPanel:AddItem( settingsDForm )

		settingsDForm:SetLabel( "Visual settings" )
		settingsDForm:SetPaintBackgroundEnabled( true )

		function settingsDForm:Paint( w, h )
			local hh = self:GetHeaderHeight()
			local c = not self:GetExpanded()
			draw.RoundedBoxEx( 4, 0, 0, w, hh, hcol, true, true, c, c )
			draw.RoundedBoxEx( 8, 0, hh, w, h - hh + 5, bgcol, false, false, true, true )
		end


		settingsDForm:NumSlider( "Minimum constraint lines width", mode .. "_hud_beam_width_min", 0.4, 20 )

		settingsDForm:CheckBox( "Show text boxes",			mode .. "_hud_show_text" )
		settingsDForm:CheckBox( "Show constraint lines",	mode .. "_hud_show_lines" )
		settingsDForm:CheckBox( "Show halos",				mode .. "_hud_show_halos" )

	local transferModeComboBox = cPanel:ComboBox( "Transfer mode:", mode .. "_transfer_mode" )
	transferModeComboBox:SetTall(30)
		transferModeComboBox:Dock(TOP)
		transferModeComboBox:AddChoice( "World-relative constraint positions preserved", 1 )
		transferModeComboBox:AddChoice( "Changed entities-relative constraint positions preserved", 2 )

	local constrBrowser = vgui.Create( "DConstraintBrowser" )
	cPanel:AddItem( constrBrowser )

	--[[
	local p = vgui.Create( "DSizeToContents", cPanel )
		cPanel:AddItem(p)
		local constrBrowser = p:Add( "DConstraintBrowser" )
			constrBrowser:SetSize( 250, 650 )
	]]
		--constrBrowser.constraintTree:SortConstrTypes()
	cPanel.constrBrowser = constrBrowser

	cPanel:InvalidateChildren( true )

end

--[[
-- TODO: Check if freeze is produced only clientside when clicking on ent with lots of constraints
-- It seems to be the case but i'm unsure if i need to check FrameTime or engine.TickInterval or something else serverside.
-- Also need to check if freeze happens on other clients
function TOOL:Think()
	if FrameTime() > 0.02 then
		print( FrameTime() )
	end
end
]]

function TOOL:DrawHUD()

	ConstraintEditor.DrawHUD(
		self:GetClientBool("hud_show_text"),
		self:GetClientBool("hud_show_lines"),
		self:GetClientBool("hud_show_halos"),
		self:GetClientNumber("hud_beam_width_min")
	)

end