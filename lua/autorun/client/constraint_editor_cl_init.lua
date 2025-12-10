
local mode = "constraint_editor" -- name of the tool

local NT = ConstraintEditor.NetTags
local BIT_COUNT_TAG			= ConstraintEditor.NetBitCounts.TAG
local BIT_COUNT_CONSTR_ID	= ConstraintEditor.NetBitCounts.CONSTR_ID


ConstraintEditor.Constrs = {}
ConstraintEditor.HoveredConstrID = -1 -- for the stool

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

-- these elseif are getting out of hand
function ConstraintEditor.HandleNetRequests( mode )

	net.Receive( "constraint_editor_net", function( len, _ )

		local tag	= net.ReadUInt( BIT_COUNT_TAG )

		local cPanel		= controlpanel.Get( mode )
		local constrBrowser	= cPanel.constrBrowser
		if not IsValid( constrBrowser ) then return end

		if tag == NT.LEFT_CLICK then

			local ent = net.ReadEntity()
			local hCID = ConstraintEditor.HoveredConstrID
			if not hCID or hCID == -1 then
				ConstraintEditor.SetEditedEntity( ent )
			else
				ConstraintEditor.RequestConstrData( hCID )
			end

		elseif tag == NT.RIGHT_CLICK then

			local hCID = ConstraintEditor.HoveredConstrID
			if not hCID or hCID < 0 then
				ConstraintEditor.SendDataToServer( NT.UNSET_EDITED_ENTITY )
			else
				ConstraintEditor.SendDataToServer( NT.REMOVE_CONSTR, hCID )
			end

		elseif tag == NT.RELOAD then

			local editor = constrBrowser.ConstraintEditor
			local constrID = editor and editor.constrID
			local ent = LocalPlayer():GetEyeTrace().Entity

			if constrID and constrID >= 0 then
				ConstraintEditor.SendDataToServer( NT.TRANSFER_CONSTR_ENTS, constrID, nil, ent )
			else
				ConstraintEditor.SendDataToServer( NT.TRANSFER_CONSTRS_ENTS, nil, nil, ent )
			end

			--[[
			local editor = constrBrowser.ConstraintEditor
			if editor then
				ConstraintEditor.SendDataToServer( NT.UPDATE_CONSTR, editor.constrID, editor:GetConstrData() )
			end
			]]

		elseif tag == NT.SET_SHOWN_CONSTRS then

			local data = net.ReadTable() or {}
			constrBrowser:SetConstrs( data )
			ConstraintEditor.Constrs = data

		elseif tag == NT.SET_EDITOR_DATA then

			local data = net.ReadTable()
			constrBrowser:ShowConstr( data[1], data[2] )

		elseif tag == NT.FORGET_CONSTR then

			local constrID = net.ReadUInt( 24 )
			constrBrowser:RemoveConstr( constrID )
			ConstraintEditor.ForgetConstr( constrID )

		elseif tag == NT.ADD_SHOWN_CONSTRS then

			local data = net.ReadTable()
			constrBrowser:AddConstrs( data )
			table.Merge( ConstraintEditor.Constrs, data )

		end

	end )

end


function ConstraintEditor.RequestConstrData( constrID )
	ConstraintEditor.SendDataToServer( NT.GET_CONSTR_DATA, constrID )
end

function ConstraintEditor.RequestDefConstrData( constrID )
	ConstraintEditor.SendDataToServer( NT.GET_DEF_CONSTR_DATA, constrID )
end

function ConstraintEditor.SetEditedEntity( ent )
	ConstraintEditor.SendDataToServer( NT.SET_EDITED_ENTITY, nil, nil, ent )
end


function ConstraintEditor.ForgetConstr( constrID )
	for constrType, constrDatas in pairs( ConstraintEditor.Constrs ) do
		if constrDatas[constrID] then
			constrDatas[constrID] = nil
		end
	end
end


-- this is cursed
function ConstraintEditor.SendDataToServer( tag, constrIDorType, data, ent )

	if not isnumber( tag ) then return end

	net.Start( "constraint_editor_net" )
		net.WriteUInt( tag, BIT_COUNT_TAG )
		if isnumber( constrIDorType ) then net.WriteUInt( constrIDorType, BIT_COUNT_CONSTR_ID ) end
		if isstring( constrIDorType ) then net.WriteString( constrIDorType ) end
		if istable( data ) then net.WriteTable( data ) end
		if isentity( ent ) then net.WriteEntity( ent ) end
	net.SendToServer()

end



--------------------------------
--        HUD Drawing         --
--------------------------------


local extractEntAndPosData, createTextData, prepareDraw, depthSortFindHover, highlightEnts

function ConstraintEditor.DrawHUD( showText, beamWidthMin, constrTypeColor )

	constrTypeColor = constrTypeColor or {}
	local boxCol	= Color( 0, 0, 0, 230 )

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

	local entColors = {
		{
			HSVToColor( 17, 0.9, 0.95 ), -- red
			HSVToColor( 200, 0.9, 0.95 ) -- blue
		},
		{
			HSVToColor( 17, 1, 1 ), -- stronger red
			HSVToColor( 200, 1, 1 ) -- stronger blue
		}
	}

	local fonts = {
		"DefaultSmall", --"DermaDefault",
		"DermaDefaultBold",
		"CreditsText",
		"Trebuchet24"
	}

	local padding = 3

	ConstraintEditor.HoveredConstrID = -1

	local cPanel = controlpanel.Get( mode )
	local constrEditor = cPanel and cPanel.constrBrowser and cPanel.constrBrowser.ConstraintEditor
	local editedConstrID = constrEditor and constrEditor.constrID or -1

	local ezData		= {}
	local textDatas		= {}
	local overlaps		= {}
	local specialEnts	= {}

	surface.SetFont( fonts[1] )


	for constrType, constrDatas in pairs( ConstraintEditor.Constrs ) do

		for constrID, constrData in pairs( constrDatas ) do

			prepareDraw( ezData, textDatas, overlaps, editedConstrID, padding, constrType, constrID, constrData )

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
				local col = entColors[math.min( weight - 1, 2 )][i]:Copy() -- >= 3 when edited
				col.a = 40 + weight * 20
				specialEnts[ent] = col
			end
		end

	end

	local CSEnts = highlightEnts( specialEnts )

	if not showText then return end
	cam.End3D()

	for e, _ in pairs( CSEnts or {} ) do
		e:Remove()
	end

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


function prepareDraw( ezData, textDatas, overlaps, editedConstrID, padding, constrType, constrID, constrData )

	local ent1, ent2, pos1, pos2, positions = extractEntAndPosData( constrType, constrData )
	if not ent1 then return end

	local isEdited = editedConstrID >= 0 and constrID == editedConstrID
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



function highlightEnts( specialEnts )

	local CSEnts = {}

	for e, col in pairs( specialEnts ) do

		if not e:IsValid() then continue end -- draws for world too, idk if that's good or not

		--[[
		if e.GetCollisionBounds then
			local mins, maxs = e:GetCollisionBounds()
			render.DrawWireframeBox( e:GetPos(), e:GetAngles(), mins, maxs, col )
		end
		]]

		local CSEnt
		if e:IsRagdoll() then
			CSEnt = ClientsideRagdoll( e:GetModel(), RENDERGROUP_TRANSLUCENT )
			if not CSEnt then continue end
			CSEnt:SetNoDraw( false )
		else
			CSEnt = ClientsideModel( e:GetModel(), RENDERGROUP_TRANSLUCENT )
			if not CSEnt then continue end
			CSEnt:SetModelScale( CSEnt:GetModelScale() )
			CSEnt:SetPos( e:GetPos() )
			CSEnt:SetAngles( e:GetAngles() )
		end

		for boneId = 0, e:GetBoneCount() - 1 do
			if CSEnt:GetBoneName( boneId ) ~= "__INVALIDBONE__" then
				local mat = e:GetBoneMatrix( boneId )
				if mat then
					CSEnt:SetBoneMatrix( boneId, mat )
				else
					-- somehow fixes bugs
					local pos, ang = e:GetBonePosition( boneId )
					CSEnt:SetBonePosition( boneId, pos, ang )
				end
			end
			CSEnt:ManipulateBoneScale( boneId, e:GetManipulateBoneScale( boneId ) )
		end

		--CSEnt:SetMaterial( "model_color" )
		CSEnt:SetMaterial( e:GetMaterial() )
		--CSEnt:SetMaterial( "models/debug/debugwhite" )
		CSEnts[CSEnt] = col
		specialEnts[e] = nil
		--C_BaseEntity::UnlinkFromHierarchy(): Entity class C_ClientRagdoll[-1] has a child class C_ClientRagdoll[-1] with the wrong parent null[-1]
	end

	for e, col in pairs( CSEnts ) do
		--render.SetColorModulation( col.r / 255, col.g / 255, col.b / 255 )

		-- check https://wiki.facepunch.com/gmod/render.SetBlend
		if not e:IsRagdoll() then
			render.OverrideColorWriteEnable( true, false )
			e:DrawModel()
			render.OverrideColorWriteEnable( false, false )
		end
	end

	for e, col in pairs( CSEnts ) do
		render.SetColorModulation( col.r / 255, col.g / 255, col.b / 255 )
		render.SetBlend( col.a / 255 )
		e:DrawModel()
		e:SetMaterial( "models/wireframe" )
		e:DrawModel()
		render.SetBlend( 1 )
	end

	return CSEnts

end