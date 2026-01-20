
local PANEL = {}

function PANEL:Init()

	self.Divider = self:Add( "DVerticalDivider" )
	self.Divider:Dock( FILL )
	self.Divider:SetTopHeight( 240 )
	self.Divider:SetTopMin( 100 )
	self.Divider:SetBottomMin( 300 )
	self.Divider:SetDividerHeight( 5 )

	self.Tree = self.Divider:Add( "DTree" )
	local browser = self

	function self.Tree:DoClick( node )
		browser:ClearEdited()
		if node.constrID then
			-- TODO: make this able to ask for data for a whole constrType
			ConstraintEditor.EditConstr( node.constrID )
		else
			for _, constrNode in pairs( node:GetChildNodes() ) do
				if constrNode.constrID then
					ConstraintEditor.GetDefaultConstrData( constrNode.constrID )
					return
				end
			end
		end
	end

	self.Divider:SetTop( self.Tree )

	self.constraintEditor = self.Divider:Add( "DConstraintEditor" )

	self.Divider:SetBottom( self.constraintEditor )

	self.constraintEditor.ConstraintBrowser = self

	-- Ordered constraint types
	self.ConstrTypes = {
		"Axis",
		"AdvBallsocket",
		"Ballsocket",
		"Elastic",
		"Hydraulic",
		"Keepupright",
		"Motor",
		"Muscle",
		"NoCollide",
		"Pulley",
		"Rope",
		"Slider",
		"Weld",
		"Winch",
	}

	self.DataPerConstrType = {
		Axis			= { icon = "icon16/cd.png", },
		AdvBallsocket	= { icon = "icon16/color_wheel.png", },
		Ballsocket		= { icon = "icon16/sport_golf.png", },
		Elastic			= { icon = "icon16/connect.png", },
		Hydraulic		= { icon = "icon16/newspaper.png", },
		Keepupright		= { icon = "icon16/arrow_up.png", },
		Motor			= { icon = "icon16/cd_burn.png", },
		Muscle			= { icon = "icon16/sport_football.png", },
		Pulley			= { icon = "icon16/vector.png", },
		Rope			= { icon = "icon16/link_break.png", },
		Slider			= { icon = "icon16/control_equalizer.png", },
		Weld			= { icon = "icon16/link.png", },
		Winch			= { icon = "icon16/webcam.png", },
		NoCollide		= { icon = "icon16/collision_off.png", },
	}

	self.defaultIcon	= "icon16/cog_add.png"

end


function PANEL:GetDataPerConstrType( constrType, create )

	if not isstring( constrType ) then return false end

	local t = self.DataPerConstrType

	if create and not t[constrType] then
		t[constrType] = {}
	end

	return t[constrType]

end

-- Adds a node for that type of constraint if not already present
function PANEL:AddConstrType( constrType )

	local data = self:GetDataPerConstrType( constrType, true )

	if not IsValid( data.panel ) then data.panel = self.Tree:AddNode( constrType, data.icon or self.defaultIcon ) end

	return data

end


function PANEL:RemoveConstrType( constrType, data )

	data = data or self:GetDataPerConstrType( constrType )

	if istable( data ) and data.panel then
		data.panel:Remove()
		data.panel = nil
		data.constrNodes = nil
	end

end


function PANEL:ClearTreeVisual()

	local rootNode = self.Tree:Root()
	rootNode.ChildNodes = nil
	rootNode:CreateChildNodes()
	return rootNode

end


function PANEL:Clear()

	self:ClearTreeVisual()

	self:ClearEdited()

	for constrType, data in pairs( self.DataPerConstrType ) do

		self:RemoveConstrType( constrType, data )

	end

end


function PANEL:SortConstrTypes()

	local rootNode = self:ClearTreeVisual()
	local constrTypes = table.GetKeys( self.DataPerConstrType )
	table.sort( constrTypes )

	for _, constrType in ipairs( constrTypes ) do

		local data = self:GetDataPerConstrType( constrType )
		local node = istable( data ) and data.panel

		if node then
			--[[
			rootNode:AddPanel( node )
			node:SetParentNode( rootNode )
			node:SetTall( rootNode:GetLineHeight() )
			node:SetRoot( rootNode:GetRoot() )
			node:SetDrawLines( not rootNode:IsRootNode() )
			rootNode:InstallDraggable( node )
			]]
			rootNode.ChildNodes:Add( node )
		end

		rootNode:InvalidateChildren() -- call this or the nodes won't show up!

	end

end


-- TODO: add checks for redundant constrIDs
function PANEL:AddConstrs( surfaceConstrData )

	if not istable( surfaceConstrData ) then return end

	for constrType, constrData in pairs( surfaceConstrData ) do

		local data = self:AddConstrType( constrType )
		data.constrNodes = data.constrNodes or {}
		local constrTypeNode = data.panel

		for constrID, _ in pairs( constrData ) do
			if not data.constrNodes[constrID] then
				data.constrNodes[constrID] = self:AddConstrToNode( constrTypeNode, constrID )
			end
		end

	end

	self:SortConstrTypes()

end


function PANEL:AddConstrToNode( constrTypeNode, constrID )

	local node = constrTypeNode:AddNode( ( "[%s]" ):format( constrID ), "icon16/application_view_columns.png" )
	node.constrID = constrID
	return node

end

--[[
function PANEL:SetConstrs( surfaceConstrData )

	self:Clear()
	self.constraintEditor:AddConstr()
	self:AddConstrs( surfaceConstrData )

end
]]


function PANEL:ClearEdited()
	self.constraintEditor:ClearEdited()
end


function PANEL:RemoveConstr( constrID )

	local editor = self.constraintEditor
	if not editor then return end

	local constrData = editor:GetConstrData()
	if constrData and editor.constrID == constrID then
		editor:ClearEdited() -- clear
	end

	local constrNode, constrNodes, constrType = self:FindConstrNode( constrID )
	if not constrNode then return end

	constrNodes[constrID] = nil
	local constrTypeNode = constrNode:GetParentNode()
	constrNode:Remove()

	if constrTypeNode:GetChildNodeCount() <= 1 then
		self:RemoveConstrType( constrType )
	end

end


function PANEL:FindConstrNode( constrID )

	for constrType, data in pairs( self.DataPerConstrType ) do

		local constrNodes = data.constrNodes
		local constrNode = constrNodes and constrNodes[constrID]
		if constrNode then return constrNode, constrNodes, constrType end

	end

end


function PANEL:FindTypeNode( constrType )

	for _, constrTypeNode in pairs( self.Tree:Root():GetChildNodes() ) do

		if constrTypeNode:GetText() == constrType then return constrTypeNode end

	end

end


-- adding constrType lets you force the browser to add a constraint node
function PANEL:SelectConstrNode( constrID, constrType )

	local constrNode = self:FindConstrNode( constrID )
	if constrType and not constrNode then
		self:AddConstrs( { [constrType] = { constrID } } )
		constrNode = self:FindConstrNode( constrID )
	end

	if not constrNode then return end

	constrNode:ExpandTo( true )

	self.Tree:SetSelectedItem( constrNode )

end


function PANEL:SelectTypeNode( constrType )

	local constrTypeNode = self:FindTypeNode( constrType )
	if not constrTypeNode then return end

	--constrTypeNode:ExpandTo( true )

	self.Tree:SetSelectedItem( constrTypeNode )

end


derma.DefineControl( "DConstraintBrowser", "", PANEL, "DPanel" )