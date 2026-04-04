ConstraintEditor.Halos = {}
ConstraintEditor.HoveredConstrInfo = { ID = -1, Type = "" } -- for the stool


hook.Add( "PreDrawHalos", "AddPropHalos", function()
	if LocalPlayer():GetActiveWeapon():GetClass() ~= "gmod_tool" or LocalPlayer():GetTool().Mode ~= ConstraintEditor.Mode then return end
	for col, entities in pairs( ConstraintEditor.Halos ) do
		halo.Add( entities, col, 3, 3, 2 )
	end
end )


-- These are functions
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

	ConstraintEditor.HoveredConstrInfo.ID	= -1
	ConstraintEditor.HoveredConstrInfo.Type	= ""

	local constrBrowser		= ConstraintEditor.GetConstrBrowser()
	local editedConstrIDs	= constrBrowser and constrBrowser.selectionData.IDs or {}

	local ezData		= {}
	local textDatas		= {}
	local overlaps		= {}
	table.Empty( ConstraintEditor.Halos )

	surface.SetFont( fonts[1] )


	for constrType, constrDatas in pairs( ConstraintEditor.constrs ) do

		for constrID, constrData in pairs( constrDatas ) do

			prepareDraw( ezData, textDatas, overlaps, editedConstrIDs, padding, constrType, constrID, constrData )

		end

	end


	-- sort the texts by depth then find hovered constraint text
	depthSortFindHover( ezData, textDatas )


	cam.Start3D()

	for constrType, constrDatas in pairs( ConstraintEditor.constrs ) do

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

	table.insert( textDatas, createTextData( constrID, constrType, str, padding, midPos3D, nil, overlaps ) or nil )

	for _, data in ipairs( { { ent = ent1, pos = pos1 }, { ent = ent2, pos = pos2 } } ) do
		if data.ent:IsWorld() then
			table.insert( textDatas, createTextData( nil, nil, "[World]", padding, data.pos, math.huge, overlaps ) or nil )
		end
	end

end



function createTextData( constrID, constrType, str, padding, pos3D, depth, overlaps )

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
		constrType	= constrType,
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
		local constrID, constrType = textData.constrID, textData.constrType
		if not constrID then continue end
		if not ezData[constrID] then continue end

		local pos, str, padding = textData.pos, textData.str, textData.padding
		local w, h = surface.GetTextSize( str )
		w, h = w + padding * 2, h + padding * 2

		if math.abs( cursorX - pos.x ) * 2 < w and math.abs( cursorY - pos.y ) * 2 < h then
			ConstraintEditor.HoveredConstrInfo	= { ID = constrID, Type = constrType }
			ezData[constrID].weight				= ezData[constrID].weight + 1
			textData.col						= Color( 70, 200, 255 )
			return
		end

	end

end