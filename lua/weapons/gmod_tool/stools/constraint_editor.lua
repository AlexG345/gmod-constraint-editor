local mode = TOOL.Mode

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
		{ name = "left" }
	}

	TOOL.ClientConVar = {
		--["width"] = 1
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
	l( "left", "Edit an entity's constraints" )
	l( "right" )
	l( "reload" )

	t, l = nil, nil

end


function TOOL:LeftClick( trace )

	local sp = game.SinglePlayer()
	local ent = trace.Entity
	if not ( ent:IsValid() or sp and ent:IsWorld() ) then return false end

	if CLIENT then return true end

	ConstraintEditor.TryCleanupTables()

	ConstraintEditor.SetEditedEntity( ent, self:GetOwner() )

	return true

end


ConstraintEditor.HandleNetRequests( mode )


local conVars = CLIENT and TOOL:BuildConVarList() or nil

function TOOL.BuildCPanel( cPanel )

	local t = "tool." .. mode .. "."
	local function l( ... )
		local a = { ... }
		if #a == 1 then table.insert( a, 1, t )
		elseif #a < 1 then return end
		return language.GetPhrase( a[1] .. a[2] )
	end

	cPanel:ToolPresets( mode, conVars )

	cPanel:Help( l( "desc" ) )

	local constrBrowser = vgui.Create( "DConstraintBrowser", cPanel )
		cPanel:AddItem( constrBrowser )
		constrBrowser:SetSize( 250, 320 )
		constrBrowser:SortConstrTypes()
	cPanel.constrBrowser = constrBrowser

	function constrBrowser.Tree:DoClick( node )

		if node.constrID then

			ConstraintEditor.RequestConstrData( node.constrID )

		end

	end


	-- Could be simplified: use CEDelete for button apply too and remove CEDuplicate

	local ButtonApply = constrBrowser:GetButtonApply()
		function ButtonApply:DoClick()
			ConstraintEditor.RequestSetConstrData( constrBrowser:GetConstrData() )
		end

	local ButtonDelete = constrBrowser:GetButtonDelete()
		function ButtonDelete:DoClick()
			local constrData = constrBrowser:GetConstrData()
			if not istable( constrData ) then return end
			local data = {
				constrID = constrData.constrID,
				CEDelete = true
			}
			ConstraintEditor.RequestSetConstrData( data )
		end

	local ButtonDuplicate = constrBrowser:GetButtonDuplicate()
		function ButtonDuplicate:DoClick()
			local constrData = constrBrowser:GetConstrData()
			if not istable( constrData ) then return end
			local data = {
				constrID = constrData.constrID,
				CEDuplicate = true
			}
			ConstraintEditor.RequestSetConstrData( data )
		end


	t, l = nil, nil

end


function TOOL:DrawHUD()

	--local ply = self:GetOwner()

	local constrBrowser = controlpanel.Get( mode ).constrBrowser
	if not constrBrowser then return end
	local constrEditor = constrBrowser.ConstraintEditor
	local cacheData = constrEditor.constrDataCache
	local newData = constrEditor.constrData
	local argsOrder = constrEditor.argsOrder

	if not ( newData and argsOrder ) then return end

	local function find( key )
		local i = argsOrder[key]
		local value = newData[i] or newData[key]
		return value ~= nil and value or cacheData[i] or cacheData[key]
	end

	-- bad for booleans
	local LPos1, LPos2, Ent1, Ent2, constrType = find( "LPos1" ) or find( "LPos" ), find( "LPos2" ) or find( "LPos4" ), find( "Ent1" ), find( "Ent2" ) or find( "Ent4" ), find( "Type" )

	if Ent1 == NULL or Ent2 == NULL or not ( Ent1 and Ent2 ) then return end

	if IsValid( Ent1 ) then
		pos1 = LPos1 and Ent1:LocalToWorld( LPos1 ) or Ent1:GetPos()
	else
		pos1 = LPos1 or LPos2
	end

	if IsValid( Ent2 ) then
		pos2 = LPos2 and Ent2:LocalToWorld( LPos2 ) or Ent2:GetPos()
	else
		pos2 = LPos2 or LPos1
	end

	local positions = {}
	table.insert( positions, pos1 )
	table.insert( positions, find( "WPos2" ) )
	table.insert( positions, find( "WPos3" ) )
	table.insert( positions, pos2 )

	cam.Start3D()

	local beamcolor = Color( 0, 200, 0, 255 )
	render.SetColorMaterial()
	render.StartBeam( #positions )
	for _, pos in ipairs( positions ) do
		render.AddBeam( pos, 1, 0, beamcolor )
	end
	render.EndBeam()

	cam.End3D()

	local bordersize	= 4
	local boxcolor		= Color( 0, 0, 0, 200 )
	local textcolor		= color_white
	local index			= math.floor(#positions / 2)
	local textPos		= ( ( positions[index] + positions[index + 1] ) / 2 ):ToScreen()
	local font			= "DermaDefault"

	if textPos.visible then draw.WordBox( bordersize, textPos.x, textPos.y, constrType, font, boxcolor, textcolor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM ) end

	for _, data in ipairs( { { ent = Ent1, pos = pos1 }, { ent = Ent2, pos = pos2 } } ) do
		if data.ent:IsWorld() then
			textPos = ( data.pos ):ToScreen()
			draw.WordBox( bordersize, textPos.x, textPos.y, "[World]", font, boxcolor, textcolor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
	end

end