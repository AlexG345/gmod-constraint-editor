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
		{ name = "right", stage = 1 },
		{ name = "right", stage = 2 },
		{ name = "reload1", stage = 1 },
		{ name = "reload2", stage = 2 },
		--{ name = "reload1_use", stage = 1 },
		--{ name = "reload2_use", stage = 2 },
	}

	TOOL.ClientConVar = {
		["hud_show_text"]		= 1,
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
	l( "left0", "Edit an entity's constraints" )
	l( "left", "Edit the constraint you're looking at,  or edit another entity's constraints" )
	l( "right", "DELETE the constraint you're facing,  or stop editing current entity" )
	l( "reload1", "Transfer all constraints from the edited entity to the one you're looking at" )
	l( "reload2", "Transfer selected constraint from the edited entity to the one you're looking at" )
	--l( "reload1_use", "Transfer all constraints from the edited entity to the one you're looking at" )
	--l( "reload2_use", "Transfer selected constraint from the edited entity to the one you're looking at" )

	t, l = nil, nil

	--local constrTypes = { "Axis", "AdvBallsocket", "Ballsocket", "Elastic", "Hydraulic", "Keepupright", "Motor", "Muscle", "Pulley", "Rope", "Slider", "Weld", "Winch", "NoCollide", "Other" }
	local constrTypes = { "Weld", "Keepupright", "Rope", "Muscle", "Hydraulic", "Winch", "Elastic", "Motor", "Axis", "Ballsocket", "AdvBallsocket", "Slider", "Other" }
	-- NoCollide is unlisted

	local hueStep = 360 / ( #constrTypes )

	TOOL.ConstrTypeColor = {}
	for i, constrType in ipairs( constrTypes ) do
		TOOL.ConstrTypeColor[constrType] = HSVToColor( ( - 0 + ( i - 1 ) * hueStep ) % 360, 0.55, 0.95 )
	end

	TOOL.ConstrTypeColor.NoCollide = HSVToColor( 0, 0, 0.5 )

end


function TOOL:LeftClick( trace )

	if SERVER then
		ConstraintEditor.TryCleanupTables()
		ConstraintEditor.LeftClick( trace.Entity, self:GetOwner() )
	end

	return true

end


function TOOL:RightClick( trace )

	if SERVER then
		ConstraintEditor.TryCleanupTables()
		ConstraintEditor.RightClick( self:GetOwner() )
	end

	return true

end


function TOOL:Reload()

	if SERVER then
		ConstraintEditor.TryCleanupTables()
		ConstraintEditor.Reload( self:GetOwner() )
	end

	return true

end


ConstraintEditor.HandleNetRequests( mode )


--local conVars = CLIENT and TOOL:BuildConVarList() or nil

function TOOL.BuildCPanel( cPanel )

	local t = "tool." .. mode .. "."
	local function l( ... )
		local a = { ... }
		if #a == 1 then table.insert( a, 1, t )
		elseif #a < 1 then return end
		return language.GetPhrase( a[1] .. a[2] )
	end

	--cPanel:ToolPresets( mode, conVars )

	cPanel:Help( l( "desc" ) )

	cPanel:CheckBox( "Enable constraint type and ID display", mode .. "_hud_show_text" )
	cPanel:NumSlider( "Minimum constraint lines width", mode .. "_hud_beam_width_min", 0.4, 20 )
	local transferModeComboBox = cPanel:ComboBox( "Transfer mode:", mode .. "_transfer_mode" )
	transferModeComboBox:SetTall(30)
		transferModeComboBox:Dock(TOP)
		transferModeComboBox:AddChoice( "World-relative constraint positions preserved", 1 )
		transferModeComboBox:AddChoice( "Changed entities-relative constraint positions preserved", 2 )

	local constrBrowser = vgui.Create( "DConstraintBrowser", cPanel )
		cPanel:AddItem( constrBrowser )
		constrBrowser:SetSize( 250, 650 )
		constrBrowser:SortConstrTypes()
	cPanel.constrBrowser = constrBrowser

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

	ConstraintEditor.DrawHUD( self:GetClientBool("hud_show_text"), self:GetClientNumber("hud_beam_width_min"), self.ConstrTypeColor )

end