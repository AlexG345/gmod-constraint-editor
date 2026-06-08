ConstraintEditor.Halos				= {}
ConstraintEditor.HoveredConstrInfo	= { ID = -1, Type = "" } -- for the stool
ConstraintEditor.HiddenConstrTypes	= {}


hook.Add( "PreDrawHalos", "AddPropHalos", function()

	local weapon = LocalPlayer():GetActiveWeapon()
	if ( not IsValid(weapon) ) or ( weapon:GetClass() ~= "gmod_tool" ) then return end
	local tool = LocalPlayer():GetTool()
	if not tool or tool.Mode ~= ConstraintEditor.Mode then return end

	for col, entities in pairs( ConstraintEditor.Halos ) do
		halo.Add( entities, col, 3, 3, 5, true, true )
	end
end )


-- These are functions
local extractEntAndPosData, createHud2DConstrData, prepareDraw, sortByDepthAndFindHoveredConstr


local beamColorsWeighted = {
	{
		start	= HSVToColor( 0, 0.9, 1 ), -- red
		final	= HSVToColor( 210, 0.9, 1 ) -- blue
	},
	{
		start	= HSVToColor( 0, 1, 1 ), -- stronger red
		final	= HSVToColor( 210, 1, 1 ) -- stronger blue
	}
}

local haloColorsWeighted = {
	{
		HSVToColor( 0, 0.4, 0.8 ), -- red (ent1)
		HSVToColor( 200, 0.4, 0.8 ) -- blue (ent2)
	},
	{
		HSVToColor( 0, 0.66, 1 ), -- stronger red (ent1)
		HSVToColor( 200, 0.66, 1 ) -- stronger blue (ent2)
	}
}

local boxColors	= {}
for i = 1,10 do
	boxColors[i] = Color( 0, 10 * i, 0, 230 )
end

-- These are ordered from smaller to bigger
local fonts = {
	"DefaultSmall", --"DermaDefault",
	"DermaDefaultBold",
	"CreditsText",
	"Trebuchet24"
}

function ConstraintEditor.DrawHUD( constrTypeLOD, showIDs, showBeams, showHalos, beamWidthMin, iconSize )

	local padding = 3

	ConstraintEditor.HoveredConstrInfo.ID	= -1
	ConstraintEditor.HoveredConstrInfo.Type	= ""

	local constrBrowser		= ConstraintEditor.GetConstrBrowser()
	local editedConstrIDs	= constrBrowser and constrBrowser.selectionData.IDs or {}

	local hud3DConstrsData	= {}
	local hud2DConstrsData	= {}
	local overlaps			= {}
	table.Empty( ConstraintEditor.Halos )

	surface.SetFont( fonts[1] )

	for constrType, constrDatas in pairs( ConstraintEditor.constrs ) do

		if ConstraintEditor.HiddenConstrTypes[constrType] then continue end

		local preStr = ( constrTypeLOD <= 1 and "" ) or ( constrTypeLOD == 2 and string.gsub( constrType, "(%u%l)%l*", "%1" ) ) or constrType

		for constrID, constrData in pairs( constrDatas ) do

			prepareDraw( hud3DConstrsData, hud2DConstrsData, overlaps, editedConstrIDs, padding, constrType, preStr, constrID, showIDs, constrData )

		end

	end

	-- Sort the 2D data by depth then find the hovered constraint
	if constrTypeLOD > 0 then
		sortByDepthAndFindHoveredConstr( hud3DConstrsData, hud2DConstrsData, iconSize )
	end

	cam.Start3D()

	for constrType, constrDatas in pairs( ConstraintEditor.constrs ) do

		if ConstraintEditor.HiddenConstrTypes[constrType] then continue end

		local constrCount	= table.Count( constrDatas )
		local visualData	= ConstraintEditor.dataPerConstrType[constrType]
		local lineColor		= visualData and visualData.lineColor or color_black
		-- local iconColor		= visualData and visualData.iconColor or color_white
		-- local iconMaterial	= constrTypeLOD == 1 and Material( visualData and visualData.icon or "" )

		for constrID, constrData in pairs( constrDatas ) do

			local hud3DConstrData = hud3DConstrsData[constrID]
			if not hud3DConstrData then continue end

			local weight	= hud3DConstrData.weight
			local colIndex	= math.min( weight - 1, 2 )

			if showBeams then

				local positions		= hud3DConstrData.positions
				local vertexCount	= #positions
				local segmentCount 	= vertexCount - 1

				local beamWidth = weight * math.Clamp( 2 - 0.1 * constrCount, beamWidthMin, 100 )

				local beamCols		= beamColorsWeighted[colIndex]
				local beamColStart	= beamCols and beamCols.start or lineColor
				local beamColEnd	= beamCols and beamCols.final or lineColor

				-- render.OverrideDepthEnable( weight > 2, true )
				render.OverrideDepthEnable( true, true )
				render.SetColorMaterial()

				render.StartBeam( vertexCount )

				for i, pos in ipairs( positions ) do

					-- ( i - 1 ) is the number of segments already drawn
					local drawCompletion = ( i - 1 ) / segmentCount

					render.AddBeam(
						pos,
						beamWidth * ( 1 - drawCompletion * 0.75 ),
						0,
						beamColStart:Lerp( beamColEnd, drawCompletion )
					)

				end

				render.EndBeam()

				render.OverrideDepthEnable( false)

			end

			-- -- Draw icons
			-- if iconMaterial then
			-- 	hud3DConstrData.mat = iconMaterial
			-- 	render.SetMaterial( iconMaterial ) -- Tell render what material we want, in this case the flash from the gravgun
			-- 	local mul = 1 + 0.1 * weight
			-- 	render.DrawSprite( hud3DConstrData.midPos3D, iconSize * mul, iconSize * mul, iconColor ) -- Draw the sprite in the middle of the map, at 16x16 in it's original colour with full alpha.
			-- end

			-- Draw halos
			if showHalos and weight > 1 then

				local ents		= hud3DConstrData.ents
				local halos		= ConstraintEditor.Halos
				local haloCols	= haloColorsWeighted[colIndex]

				for i, ent in ipairs( ents ) do

					local col = haloCols[i]

					if not halos[col] then halos[col] = {} end

					halos[col][ent] = ent -- avoid duplicates by using ent as key

				end

			end

		end

	end


	if constrTypeLOD == 1 then

		for _, hud2DConstrData in pairs( hud2DConstrsData ) do

			local constrType	= hud2DConstrData.constrType
			local constrID		= hud2DConstrData.constrID

			if ConstraintEditor.HiddenConstrTypes[constrType] then continue end

			local hud3DConstrData = hud3DConstrsData[constrID]
			if not hud3DConstrData then continue end

			local visualData	= ConstraintEditor.dataPerConstrType[constrType]
			local iconMaterial	= Material( visualData and visualData.icon or "" )
			local iconColor		= visualData and visualData.iconColor or color_white

			-- Draw icons
			render.SetMaterial( iconMaterial ) -- Tell render what material we want, in this case the flash from the gravgun
			local mul = 1 + 0.1 * hud3DConstrData.weight
			render.DrawSprite( hud3DConstrData.midPos3D, iconSize * mul, iconSize * mul, iconColor ) -- Draw the sprite in the middle of the map, at 16x16 in it's original colour with full alpha.

		end

	end

	cam.End3D()

	if not ( showIDs or constrTypeLOD > 1 ) then return end

	for i, hud2DConstrData in pairs( hud2DConstrsData ) do

		local pos, constrID = hud2DConstrData.pos, hud2DConstrData.constrID
		local weight = hud3DConstrsData[constrID] and hud3DConstrsData[constrID].weight or 1
		local b = #boxColors - 1
		local boxColorIndex = 1 + math.abs( ( hud2DConstrData.overlapNum - b ) % ( 2 * b ) - b )

		draw.WordBox(
			padding,
			pos.x,
			pos.y,
			hud2DConstrData.str,
			fonts[weight],
			boxColors[boxColorIndex],
			--boxColors[1 + hud2DConstrData.overlapNum % #boxColors],
			hud2DConstrData.col or color_white,
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER
		)

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


function prepareDraw( hud3DConstrsData, hud2DConstrsData, overlaps, editedConstrIDs, padding, constrType, preStr, constrID, showIDs, constrData )

	local ent1, ent2, pos1, pos2, positions = extractEntAndPosData( constrType, constrData )
	if not ent1 then return end

	local isEdited	= editedConstrIDs[constrID]
	local weight	= isEdited and 3 or 1

	local midIndex	= math.floor( #positions / 2 )
	local midPos3D	= ( positions[midIndex] + positions[midIndex + 1] ) / 2

	hud3DConstrsData[constrID] = {
		ents		= { ent1, ent2 },
		positions	= positions,
		weight		= weight,
		midPos3D	= midPos3D,
	}

	if not hud2DConstrsData then return end

	local str		= showIDs and ( preStr .. ( " [" .. constrID or "?" ) .. "]" ) or preStr
	str = string.TrimLeft( str, " " )

	table.insert( hud2DConstrsData, createHud2DConstrData( constrID, constrType, str, padding, midPos3D, nil, overlaps ) or nil )

	for ent, pos in pairs( { [ent1] = pos1, [ent2] = pos2 } ) do
		if ent:IsWorld() then
			table.insert( hud2DConstrsData, createHud2DConstrData( nil, nil, "(World)", padding, Vector( pos ), math.huge, nil ) or nil )
		end
	end

end



function createHud2DConstrData( constrID, constrType, str, padding, pos3D, depth, overlaps )

	if not depth then
		depth = (pos3D - EyePos()):LengthSqr()
	end

	local overlapID
	if overlaps then
		overlapID = string.format("%s_%s_%s", math.floor( pos3D.x ), math.floor( pos3D.y ), math.floor( pos3D.z ) )
		overlaps[overlapID] = overlaps[overlapID] and overlaps[overlapID] + 1 or 0
		-- pos2D.y = pos2D.y + overlaps[overlapID] * 20
		pos3D.z = pos3D.z - overlaps[overlapID] * (math.sqrt(depth) * 0.035)
	end

	local pos2D = pos3D:ToScreen()
	if not pos2D.visible then return end

	return {
		constrID	= constrID or -1,
		constrType	= constrType,
		str			= str or "",
		padding		= padding or 0,
		pos			= pos2D,
		depth		= depth,
		overlapNum	= overlapID and overlaps[overlapID] or 0
	}

end



function sortByDepthAndFindHoveredConstr( hud3DConstrsData, hud2DConstrsData, iconSize )

	table.sort( hud2DConstrsData, function( a, b )
		return a.depth > b.depth
	end )

	local cursorX, cursorY	= input.GetCursorPos()

	for hud2DConstrDataIndex = #hud2DConstrsData, 1, -1 do

		local hud2DConstrData = hud2DConstrsData[hud2DConstrDataIndex] or {}
		local constrID, constrType = hud2DConstrData.constrID, hud2DConstrData.constrType
		if not constrID then continue end
		if not hud3DConstrsData[constrID] then continue end

		local extraSize	= 2 * hud2DConstrData.padding

		local w, h		= surface.GetTextSize( hud2DConstrData.str )
		if w == 0 then
			extraSize = 530 * iconSize / math.sqrt( hud2DConstrData.depth )
			h = 0
		end
		w, h			= w + extraSize, h + extraSize

		local pos		= hud2DConstrData.pos

		if math.abs( cursorX - pos.x ) * 2 < w and math.abs( cursorY - pos.y ) * 2 < h then
			ConstraintEditor.HoveredConstrInfo	= { ID = constrID, Type = constrType }
			hud3DConstrsData[constrID].weight		= hud3DConstrsData[constrID].weight + 1
			hud2DConstrData.col						= Color( 70, 200, 255 )
			return
		end

	end

end