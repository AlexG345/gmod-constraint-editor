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
		{ name = "left" },
		{ name = "right" }
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
	l( "left", "Edit an entity's constraints or select a constraint" )
	l( "right", "Unselect the edited entity or DELETE a constraint" )
	l( "reload" )

	t, l = nil, nil

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

-- apply changes?
-- function TOOL:Reload() end


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

	local constrBrowser = vgui.Create( "DConstraintBrowser", cPanel )
		cPanel:AddItem( constrBrowser )
		constrBrowser:SetSize( 250, 650 )
		constrBrowser:SortConstrTypes()
	cPanel.constrBrowser = constrBrowser

end

-- need to check if constraint still exists somehow
function TOOL:DrawHUD()

	local bordersize	= 4
	local boxcolor		= Color( 0, 0, 0, 200 )
	local color_green	= Color( 40, 250, 40 )
	local color_dgreen	= Color( 20, 200, 90 )
	local color_blue	= Color( 70, 200, 255 )
	local font1		= "DermaDefault"
	local font2		= "DermaDefaultBold"
	local font3		= "CreditsText"
	local font4		= "Trebuchet24"
	local overlaps		= {}
	local textDatas		= {}

	local canHover		= true
	ConstraintEditor.HoveredConstrID = -1

	local cPanel = controlpanel.Get( mode )
	local constrEditor = cPanel and cPanel.constrBrowser and cPanel.constrBrowser.ConstraintEditor
	local editedConstrID = constrEditor and constrEditor.constrID or -1

	surface.SetFont( font1 )

	for constrType, constrDatas in pairs( ConstraintEditor.Constrs ) do

		for constrID, constrData in pairs( constrDatas ) do

			local Ent1, Ent2, LPos1, LPos2, WPos2, WPos3 = unpack( constrData )

			if not ( isentity( Ent1 ) and isentity( Ent2 ) ) then return end
			if Ent1 == NULL or Ent2 == NULL then return end

			local pos1, pos2

			if IsValid( Ent1 ) then
				pos1 = LPos1 and Ent1:LocalToWorld( LPos1 ) or Ent1:GetPos()
			else
				pos1 = LPos1 or LPos2
			end

			if IsValid( Ent2 ) then
				pos2 = LPos2 and Ent2:LocalToWorld( LPos2 ) or Ent2:GetPos()
			else
				pos2 = LPos2 or LPos1 or pos1 - 100 * vector_up
			end

			local positions = {}
			table.insert( positions, pos1 )
			table.insert( positions, WPos2 )
			table.insert( positions, WPos3 )
			table.insert( positions, pos2 )

			local isEdited = editedConstrID > 0 and constrID == editedConstrID
			local isHovered	= false
			local index		= math.floor( #positions / 2 )
			local midPos	= ( positions[index] + positions[index + 1] ) / 2
			local textPos	= midPos:ToScreen()

			local id = string.format("%s_%s_%s", math.floor( midPos.x ), math.floor( midPos.y ), math.floor( midPos.z ) )
			overlaps[id] = overlaps[id] and overlaps[id] + 1 or 0
			textPos.y = textPos.y + overlaps[id] * 20

			if textPos.visible then

				local text = constrType .. ( " [" .. constrID or "?" ) .. "]"

				local w, h = surface.GetTextSize( text )
				w, h = w + bordersize * 2, h + bordersize * 2

				local cursorPos = {}
				cursorPos.x, cursorPos.y = input.GetCursorPos()

				isHovered = canHover and math.abs( cursorPos.x - textPos.x ) * 2 < w and math.abs( cursorPos.y - textPos.y ) * 2 < h

				if isHovered then
					canHover = false
					ConstraintEditor.HoveredConstrID = constrID
				end

				local font = ( isEdited and isHovered and font4 ) or isEdited and font3 or isHovered and font2 or font1
				textDatas[constrID] = { { textPos, text, font, isEdited and color_blue } }

				for _, data in ipairs( { { ent = Ent1, pos = pos1 }, { ent = Ent2, pos = pos2 } } ) do
					if data.ent:IsWorld() then
						textPos = data.pos:ToScreen()
						textDatas[constrID][2] = { textPos, "[World]", font1 }
					end
				end

			end

			cam.Start3D()

			local beamWidth = isHovered and 2 or 0.9
			if isEdited then beamWidth = beamWidth + 0.4 end
			local beamColor = isEdited and color_white or  isHovered and color_green or color_dgreen

			render.SetColorMaterial()
			render.StartBeam( #positions )
			for _, pos in ipairs( positions ) do
				render.AddBeam( pos, beamWidth, 0, beamColor )
			end
			render.EndBeam()

			if isEdited or isHovered then
				for _, e in ipairs( { Ent1, Ent2 } ) do
					if e.GetModelRenderBounds then -- draws for world too, idk if that's good or not
						local mins, maxs = e:GetModelRenderBounds()
						render.DrawWireframeBox( e:GetPos(), e:GetAngles(), mins, maxs, isEdited and color_white or color_green )
					end
				end
			end

			cam.End3D()

		end

	end

	for constrID, textData in pairs( textDatas ) do

		local textColor		= color_white
		local constrTData	= textData[1]
		local entTData		= textData[2]

		if constrTData then
			local textPos, text, font, col = unpack( constrTData )
			draw.WordBox( bordersize, textPos.x, textPos.y, text, font, boxcolor, col or textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end

		if entTData then
			local textPos, text, font = unpack( entTData )
			draw.WordBox( bordersize, textPos.x, textPos.y, text, font, boxcolor, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end

	end
end
