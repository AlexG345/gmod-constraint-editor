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
		--{ name = "left" }
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

	local ent = trace.Entity
	if not ( ent:IsValid() or ent:IsWorld() ) then return false end

	if CLIENT and not game.SinglePlayer() then return true end

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

	local applyButton = constrBrowser:GetApplyButton()
		function applyButton:DoClick()
			ConstraintEditor.RequestSetConstrData( constrBrowser:GetConstrData() )
		end

	t, l = nil, nil

end