local NT = ConstraintEditor.NetTags
local BIT_COUNT = ConstraintEditor.NetBitCounts


ConstraintEditor.Constrs = {}
ConstraintEditor.HoveredConstrID = -1 -- for the stool
ConstraintEditor.Halos = {}

ConstraintEditor.EditModes = {
	NONE	= 0,
	SINGLE	= 1,
	MANY	= 2
}

--[[
function ConstraintEditor.GetTestTable( constrID )
	return {
	[7]			=	500,
	[10]		=	100,
	[11]		=	"cable/cable",
	[12]		=	false,
	Type		=	"Rope",
	constrID	=	constrID
	}
end
]]


-- Gets the constraint browser vgui element from the main menu
local function getConstrBrowser()
	local cPanel = controlpanel.Get( ConstraintEditor.Mode )
	return cPanel and cPanel.constrBrowser
end


-- Gets the constraint editor vgui element from the main menu
local function getConstrEditor()
	local constrBrowser = getConstrBrowser()
	return constrBrowser and constrBrowser.constraintEditor
end


-- Checks whether the player is looking at a constraint text bubble or not, and gets the corresponding constraint creation ID.
--
-- Returns:
--	(boolean): true if a constraint is being hovered, false otherwise
--	hCID (int | nil): the hovered constraint ID
local function isHoveringConstr()
	local hCID = ConstraintEditor.HoveredConstrID
	return hCID and hCID >= 0, hCID
end


-- Put many constraint creation IDs into an appropriate format for the net send functions
--
-- Arguments:
--	constrIDs (table): A table whose keys are constraint creation IDs, and whose values should be boolean (true to add the constraint creation ID to the final result)
--
-- Returns:
--	(tuple): The unpacked table of constraint IDs:
--		First table is { how many IDs will be sent, max entity (constraint) count }
--		Consecutive tables are { creation ID of the constraint, maximum bit count for a creation ID }
function ConstraintEditor.ToNetConstrIDs( constrIDs )

	if not constrIDs then return end

	local tab = { { 0, BIT_COUNT.ENT_COUNT } }
	local constrCount = 0

	for constrID, add in pairs( constrIDs ) do
		if add then
			table.insert( tab, ConstraintEditor.ToNetConstrID( constrID ) )
			constrCount = constrCount + 1
		end
	end

	tab[1][1] = constrCount
	return unpack( tab )
end



local netFunctions = {

	[NT.LEFT_CLICK] = function()
		local ent = net.ReadEntity()
		-- If the player is pressing shift, assume that they want to edit an extra entity on top of any currently edited ones.
		local clearSelection = not LocalPlayer():KeyDown( IN_SPEED )
		local constrHovered, hoveredConstrID = isHoveringConstr()

		if constrHovered then
			if clearSelection then
				local constrEditor	= getConstrEditor()
				constrEditor:ClearEdited()
			end
			ConstraintEditor.EditConstr( hoveredConstrID )
			-- server will do: ConstraintEditor.SendDataToClient( NT.FILL_EDITOR, { { constrData, desc.Args } }, ply )
		else
			if clearSelection then
				ConstraintEditor.SendDataToServer( NT.CLEAR_EDITED_ENTS )
			end
			ConstraintEditor.AddEditedEntity( ent )
		end
	end,

	[NT.RIGHT_CLICK] = function()

		local constrHovered, hoveredConstrID = isHoveringConstr()

		if constrHovered then
			ConstraintEditor.SendDataToServer(
				NT.REMOVE_CONSTR,
				ConstraintEditor.ToNetConstrID( hoveredConstrID )
			)
		else
			ConstraintEditor.SendDataToServer(
				NT.CLEAR_EDITED_ENTS
			)
		end
	end,

	[NT.RELOAD] = function()

		local constrEditor	= getConstrEditor()
		local constrID		= constrEditor and constrEditor.constrID

		local ply = LocalPlayer()
		local ent = ply:GetEyeTrace().Entity

		if constrID and constrID >= 0 then
			ConstraintEditor.SendDataToServer(
				NT.TRANSFER_CONSTR_ENTS,
				ConstraintEditor.ToNetConstrID( constrID )
				{ ent }
			)
		else
			ConstraintEditor.SendDataToServer(
				NT.TRANSFER_CONSTRS_ENTS,
				{ ent }
			)
		end

	end,

	[NT.CLEAR_SHOWN_CONSTRS] = function()
		ConstraintEditor.Constrs = {}

		local constrBrowser	= getConstrBrowser()
		if IsValid( constrBrowser ) then constrBrowser:Clear() end
	end,

	[NT.FILL_EDITOR] = function()
		local data = net.ReadTable()

		local constrEditor = getConstrEditor()
		if not ( data and IsValid( constrEditor ) ) then return end

		constrEditor:Fill( data[1], data[2] )
	end,

	[NT.FORGET_CONSTR] = function()
		local constrID = net.ReadUInt( BIT_COUNT.CONSTR_ID )

		local constrBrowser	= getConstrBrowser()
		if IsValid( constrBrowser ) then constrBrowser:RemoveConstr( constrID ) end

		ConstraintEditor.ForgetConstr( constrID )
	end,

	[NT.ADD_SHOWN_CONSTRS] = function()
		local data = net.ReadTable()

		local constrBrowser	= getConstrBrowser()
		if IsValid( constrBrowser ) then constrBrowser:AddConstrs( data ) end

		table.Merge( ConstraintEditor.Constrs, data )
	end

}


function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, _ )

		local tag = net.ReadUInt( BIT_COUNT.TAG )
		netFunctions[tag]()

	end )

end


-- Select or unselect constraints by their creation IDs, for modification through the menu.
-- Assumes the constraint creation IDs correspond to constraints of the same type.
--
-- Arguments:
--	constrIDs (table): A table whose keys are constraint creation IDs, and whose values should be boolean (true to enable edit, false to disable)
--	constrType (string): The shared type of constraint (e.g. Rope, Weld, ...)
--
-- Returns:
--	(nil)
function ConstraintEditor.SetEnabledConstrs( constrIDs, constrType )

	local constrEditor = getConstrEditor()
	if not constrEditor then return end

	local dataNeeded = constrEditor:SetEnabledIDs( constrIDs, constrType )

	if not dataNeeded then return end

	ConstraintEditor.EditConstrs( constrIDs )

end


function ConstraintEditor.EditConstrs( constrIDs )
	ConstraintEditor.SendDataToServer(
		NT.GET_DATA_FOR_EDITOR,
		ConstraintEditor.ToNetConstrIDs( constrIDs )
	)
end


-- outdated
function ConstraintEditor.EditConstr( constrID )
	print(ConstraintEditor.ToNetConstrIDs( { [constrID] = true } ))
	ConstraintEditor.SendDataToServer(
		NT.GET_DATA_FOR_EDITOR,
		ConstraintEditor.ToNetConstrIDs( { [constrID] = true } )
	)
end


-- outdated
function ConstraintEditor.GetDefaultConstrData( constrID )
	ConstraintEditor.SendDataToServer(
		NT.GET_DEF_DATA_FOR_EDITOR,
		ConstraintEditor.ToNetConstrIDs( { [constrID] = true } )
	)
end


function ConstraintEditor.AddEditedEntity( ent )
	ConstraintEditor.SendDataToServer(
		NT.ADD_EDITED_ENTITY,
		{ ent }
	)
end


function ConstraintEditor.ForgetConstr( constrID )
	for constrType, constrDatas in pairs( ConstraintEditor.Constrs ) do
		if constrDatas[constrID] then
			constrDatas[constrID] = nil
		end
	end
end


function ConstraintEditor.SendDataToServer( tag, ... )

	ConstraintEditor.NetStartWrite( tag, ... )

	net.SendToServer()

end


--------------------------------
--        HUD Drawing         --
--------------------------------


hook.Add( "PreDrawHalos", "AddPropHalos", function()
	if LocalPlayer():GetActiveWeapon():GetClass() ~= "gmod_tool" or LocalPlayer():GetTool().Mode ~= ConstraintEditor.Mode then return end
	for col, entities in pairs( ConstraintEditor.Halos ) do
		halo.Add( entities, col, 3, 3, 2 )
	end
end )


-- Local functions
local extractEntAndPosData, createTextData, prepareDraw, depthSortFindHover


local beamColors = {
	{
		start	= HSVToColor( 0, 0.9, 1 ), -- red
		final	= HSVToColor( 210, 0.9, 1 ) -- blue
	},
	{
		start	= HSVToColor( 0, 1, 1 ), -- stronger red
		final	= HSVToColor( 210, 1, 1 ) -- stronger blue
	}
}

local haloColors = {
	{
		HSVToColor( 17, 0.5, 1 ), -- red (ent1)
		HSVToColor( 200, 0.5, 1 ) -- blue (ent2)
	},
	{
		HSVToColor( 0, 0.8, 1 ), -- stronger red (ent1)
		HSVToColor( 200, 0.8, 1 ) -- stronger blue (ent2)
	}
}

local boxCol	= Color( 0, 0, 0, 230 )

function ConstraintEditor.DrawHUD( showText, beamWidthMin, constrTypeColor )

	constrTypeColor = constrTypeColor or {}

	local fonts = {
		"DefaultSmall", --"DermaDefault",
		"DermaDefaultBold",
		"CreditsText",
		"Trebuchet24"
	}

	local padding = 3

	ConstraintEditor.HoveredConstrID = -1

	local constrBrowser		= getConstrBrowser()
	local constrEditor		= constrBrowser and constrBrowser.constraintEditor
	local editedConstrIDs	= constrEditor and constrEditor.constrIDs or {}

	local ezData		= {}
	local textDatas		= {}
	local overlaps		= {}
	table.Empty( ConstraintEditor.Halos )

	surface.SetFont( fonts[1] )


	for constrType, constrDatas in pairs( ConstraintEditor.Constrs ) do

		for constrID, constrData in pairs( constrDatas ) do

			prepareDraw( ezData, textDatas, overlaps, editedConstrIDs, padding, constrType, constrID, constrData )

		end

	end


	-- sort the texts by depth then find hovered constraint text
	depthSortFindHover( ezData, textDatas )


	cam.Start3D()

	for constrType, constrDatas in pairs( ConstraintEditor.Constrs ) do

		local constrCount = table.Count( constrDatas )
		local constrColor = constrTypeColor[constrType] or constrTypeColor.Other or color_black

		for constrID, constrData in pairs( constrDatas ) do

			local data = ezData[constrID]
			if not data then continue end
			local ents, positions, weight = data.ents, data.positions, data.weight

			local beamWidth = weight * math.Clamp( 2 - 0.1 * constrCount, beamWidthMin, 100 )

			local beamColDuo	= beamColors[math.min( weight - 1, 2 )]
			local beamColStart	= beamColDuo and beamColDuo.start or constrColor
			local beamColEnd	= beamColDuo and beamColDuo.final or constrColor

			local vertexCount = #positions

			render.OverrideDepthEnable( weight > 2, true )

			render.SetColorMaterial()
			render.StartBeam( vertexCount )
			for i, pos in ipairs( positions ) do
				local t = ( i - 1 ) / ( vertexCount - 1 )
				render.AddBeam( pos, beamWidth * ( 1 - t * 0.75 ), 0, beamColStart:Lerp( beamColEnd, t ) )
			end
			render.EndBeam()

			render.OverrideDepthEnable( false)

			if weight <= 1 then continue end

			for i, ent in ipairs( ents ) do
				local col = haloColors[math.min( weight - 1, 2 )][i]:Copy() -- >= 3 when edited
				col.a = 180 + weight * 40
				local ceHalos = ConstraintEditor.Halos
				if not ceHalos[col] then ceHalos[col] = {} end
				table.insert( ceHalos[col], ent )
			end
		end

	end

	if not showText then return end
	cam.End3D()

	for i, textData in pairs( textDatas ) do

		local pos, str, constrID, col = textData.pos, textData.str, textData.constrID, textData.col or color_white
		local weight = ezData[constrID] and ezData[constrID].weight or 1

		draw.WordBox( padding, pos.x, pos.y, str, fonts[weight], boxCol, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

	end

end



function extractEntAndPosData( constrType, constrData )

	local ent1, ent2, LPos1, LPos2, WPos1, WPos2, LocalAxis = unpack( constrData, 1, 7 )

	if constrType == "Keepupright" then ent2 = game.GetWorld() end

	if not ( isentity( ent1 ) and isentity( ent2 ) ) then return end
	if ent1 == NULL or ent2 == NULL then return end

	local pos1 = IsValid( ent1 ) and ent1:LocalToWorld( LPos1 or vector_origin ) or LPos1 or LPos2
	local pos2 = LocalAxis and IsValid( ent1 ) and ent1:LocalToWorld( LocalAxis ) or IsValid( ent2 ) and ent2:LocalToWorld( LPos2 or vector_origin ) or LPos2 or LPos1 or pos1 - 100 * vector_up
	pos1 = pos1 or pos2 - 100 * vector_up

	local positions = { pos1 }
	table.insert( positions, WPos1 )
	table.insert( positions, WPos2 )
	table.insert( positions, pos2 )

	return ent1, ent2, pos1, pos2, positions

end


function prepareDraw( ezData, textDatas, overlaps, editedConstrIDs, padding, constrType, constrID, constrData )

	local ent1, ent2, pos1, pos2, positions = extractEntAndPosData( constrType, constrData )
	if not ent1 then return end

	local isEdited = editedConstrIDs[constrID]
	local weight = isEdited and 3 or 1

	ezData[constrID] = {
		ents		= { ent1, ent2 },
		positions	= positions,
		weight		= weight
	}

	local str		= constrType .. ( " [" .. constrID or "?" ) .. "]"
	local midIndex	= math.floor( #positions / 2 )
	local midPos3D	= ( positions[midIndex] + positions[midIndex + 1] ) / 2

	table.insert( textDatas, createTextData( constrID, str, padding, midPos3D, nil, overlaps ) or nil )

	for _, data in ipairs( { { ent = ent1, pos = pos1 }, { ent = ent2, pos = pos2 } } ) do
		if data.ent:IsWorld() then
			table.insert( textDatas, createTextData( nil, "[World]", padding, data.pos, math.huge, overlaps ) or nil )
		end
	end

end



function createTextData( constrID, str, padding, pos3D, depth, overlaps )

	local pos2D = pos3D:ToScreen()
	if not pos2D.visible then return end

	if overlaps then
		local overlapID = string.format("%s_%s_%s", math.floor( pos3D.x ), math.floor( pos3D.y ), math.floor( pos3D.z ) )
		overlaps[overlapID] = overlaps[overlapID] and overlaps[overlapID] + 1 or 0
		pos2D.y = pos2D.y + overlaps[overlapID] * 20
	end

	if not depth then
		pos3D:Sub(EyePos())
		depth = pos3D:LengthSqr()
	end

	return {
		constrID	= constrID or -1,
		str			= str or "",
		padding		= padding or 4,
		pos			= pos2D,
		depth		= depth,
	}

end



function depthSortFindHover( ezData, textDatas )

	table.sort( textDatas, function( a, b )
		return a.depth > b.depth
	end )

	local cursorX, cursorY = input.GetCursorPos()

	for i = #textDatas, 1, -1 do

		local textData = textDatas[i] or {}
		local constrID = textData.constrID
		if not constrID then continue end
		if not ezData[constrID] then continue end

		local pos, str, padding = textData.pos, textData.str, textData.padding
		local w, h = surface.GetTextSize( str )
		w, h = w + padding * 2, h + padding * 2

		if math.abs( cursorX - pos.x ) * 2 < w and math.abs( cursorY - pos.y ) * 2 < h then
			ConstraintEditor.HoveredConstrID	= constrID
			ezData[constrID].weight				= ezData[constrID].weight + 1
			textData.col						= Color( 70, 200, 255 )
			return
		end

	end

end