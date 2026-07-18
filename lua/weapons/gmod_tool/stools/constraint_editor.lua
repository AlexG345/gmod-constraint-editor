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
		{ name = "left0",		stage = 0 },
		{ name = "left",		stage = 1 },
		{ name = "left",		stage = 2 },
		{ name = "left_shift",	stage = 1,	icon = "gui/lmb.png" },
		{ name = "left_shift",	stage = 2,	icon = "gui/lmb.png" },
		{ name = "right",		stage = 1 },
		{ name = "right",		stage = 2 },
		{ name = "right_shift",	stage = 1,	icon = "gui/rmb.png" },
		{ name = "right_shift",	stage = 2,	icon = "gui/rmb.png" },
		{ name = "reload1",		stage = 1 },
		{ name = "reload2",		stage = 2 },
		--{ name = "reload1_use", stage = 1 },
		--{ name = "reload2_use", stage = 2 },
	}

	TOOL.ClientConVar = {
		["hud_constr_type_lod"]	= 3,
		["hud_show_ids"]		= 1,
		["hud_show_lines"]		= 1,
		["hud_show_halos"]		= 1,
		["hud_beam_width_min"]	= 1,
		["hud_icon_size"]		= 12,
		["transfer_mode"]		= 1,
		["transfer_delete"]		= 1,
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
	l( "left0", "Select an entity, letting you see its constraints" )
	l( "left", "Set selection to a single constraint/entity" )
	l( "left_shift", "+ " .. ( input.LookupBinding( "+speed" ) or "Sprint" ) .. ": Select or unselect a constraint/entity without clearing your selection" )
	-- l( "shift", "Press " .. ( input.LookupBinding( "+speed" ) or "Sprint" ) .. " to not clear selection on left click" )
	l( "right", "Delete the constraint you're looking at, or clear your selection" )
	l( "right_shift", "+ " .. ( input.LookupBinding( "+speed" ) or "Sprint" ) .. ": Unselect all constraints linked to the entity you're looking at" )
	l( "reload1", "Transfer all constraints from your entity selection to the entity you're looking at" )
	l( "reload2", "Transfer selected constraint(s) to the entity you're looking at" )
	--l( "reload1_use", "Transfer all constraints from the edited entity to the one you're looking at" )
	--l( "reload2_use", "Transfer selected constraint from the edited entity to the one you're looking at" )

	t, l = nil, nil

end


function TOOL:LeftClick( trace )

	if SERVER then
		ConstraintEditor.TryCleanupTables()

		local ply = self:GetOwner()
		if ConstraintEditor.NetStartWrite( ConstraintEditor.netTags.TOOLGUN_LEFT_CLICK, ply ) then
			net.WriteEntity( trace.Entity )
			net.Send( ply )
		end
	end

	return true

end


function TOOL:RightClick( trace )

	if SERVER then
		ConstraintEditor.TryCleanupTables()

		local ply = self:GetOwner()
		if ConstraintEditor.NetStartWrite( ConstraintEditor.netTags.TOOLGUN_RIGHT_CLICK, ply ) then
			net.WriteEntity( trace.Entity )
			net.Send( ply )
		end
	end

	return true

end


function TOOL:Reload( trace )

	if SERVER then
		ConstraintEditor.TryCleanupTables()
		local ply = self:GetOwner()
		if ConstraintEditor.NetStartWrite( ConstraintEditor.netTags.TOOLGUN_RELOAD, ply ) then
			net.WriteEntity( trace.Entity )
			net.Send( ply )
		end
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

		settingsDForm:CheckBox( "Show entities' halos",				mode .. "_hud_show_halos" )
		settingsDForm:CheckBox( "Show constraints' IDs",		mode .. "_hud_show_ids" )
		local showLinesCheckBox = settingsDForm:CheckBox( "Show constraints' lines",	mode .. "_hud_show_lines" )

		local linesWidthSlider	= settingsDForm:NumSlider( "Minimum constraint lines width", mode .. "_hud_beam_width_min", 0.4, 20, 1 )

		function showLinesCheckBox:OnChange( checked )
			linesWidthSlider:SetEnabled( checked )
		end


		local constrTypeLODComboBox, constrTypeLabel = settingsDForm:ComboBox( "Constraints types' display: ", mode .. "_hud_constr_type_lod" )
			constrTypeLabel:SetWide( 140 )
			constrTypeLODComboBox:SetTall( 20 )
			constrTypeLODComboBox:Dock( TOP )
			constrTypeLODComboBox:SetSortItems( false )
			constrTypeLODComboBox:AddChoice( "Hidden", 0, false, "icon16/cross.png" )
			constrTypeLODComboBox:AddChoice( "Icons", 1, false, "icon16/color_swatch.png" )
			constrTypeLODComboBox:AddChoice( "Abbreviated names", 2, false, "icon16/style.png" )
			constrTypeLODComboBox:AddChoice( "Entire names", 3, false, "icon16/style_add.png" )

		local iconSizeSlider = settingsDForm:NumSlider( "Constraints types' icon size", mode .. "_hud_icon_size", 1, 20, 1 )

		-- This is done like that and not with OnSelect because OnSelect
		-- does not handle convar changes done without using the combo box
		local oSV = constrTypeLODComboBox.SetValue
		function constrTypeLODComboBox:SetValue( value )
			oSV( self, value )
			iconSizeSlider:SetEnabled( value == self:GetOptionTextByData( 1 ) )
		end

	local transferModeComboBox = cPanel:ComboBox( "Entity transfer:", mode .. "_transfer_mode" )
		transferModeComboBox:SetTall( 20 )
		transferModeComboBox:Dock( TOP )
		transferModeComboBox:AddChoice( "Preserve world positions", 1, false, "icon16/world.png" )
		transferModeComboBox:AddChoice( "Preserve local positions (from target to destination entity)", 2, false, "icon16/house_link.png" )

	local constrBrowser = vgui.Create( "constraint_editor_constraint_browser" )
	cPanel:AddItem( constrBrowser )

	--[[
	local p = vgui.Create( "DSizeToContents", cPanel )
		cPanel:AddItem(p)
		local constrBrowser = p:Add( "constraint_editor_constraint_browser" )
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
		self:GetClientNumber("hud_constr_type_lod"),
		self:GetClientBool("hud_show_ids"),
		self:GetClientBool("hud_show_lines"),
		self:GetClientBool("hud_show_halos"),
		self:GetClientNumber("hud_beam_width_min"),
		self:GetClientNumber("hud_icon_size")
	)

end