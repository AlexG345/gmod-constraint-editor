
local PANEL = {}

function PANEL:Init()

	self.Divider = self:Add( "DHorizontalDivider" )
	self.Divider:Dock( FILL )
	self.Divider:SetLeftWidth( 110 )
	self.Divider:SetLeftMin( 70 )
	self.Divider:SetRightMin( 195 )
	self.Divider:SetDividerWidth( 3 )

	self.Tree = self.Divider:Add( "DTree" )

	function self.Tree:DoClick( node )
		if node.constrID then
			ConstraintEditor.RequestConstrData( node.constrID )
		end
	end

	self.Divider:SetLeft( self.Tree )

	self.ConstraintEditor = self.Divider:Add( "DConstraintEditor" )
	self.Divider:SetRight( self.ConstraintEditor )

	self.ConstraintEditor.ConstraintBrowser = self

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

-- Adds a "folder" for that type of constraint if not already present
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

	self.ConstraintEditor.Properties:Clear()

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


-- todo: add checks for redundant constrIDs
function PANEL:AddConstrs( surfaceConstrData )

	if not istable( surfaceConstrData ) then return end

	for constrType, constrIDs in pairs( surfaceConstrData ) do

		local data = self:AddConstrType( constrType )

		for _, constrID in ipairs( constrIDs ) do

			local node = data.panel:AddNode( ( "[%s]" ):format( constrID ), "icon16/application_view_columns.png" )
			node.constrID = constrID

		end

	end

	self:SortConstrTypes()

end


function PANEL:SetConstrs( surfaceConstrData )

	self:Clear()
	self:AddConstrs( surfaceConstrData )

end


function PANEL:ShowConstr( codedData, args )

	--self:SelectConstrNode( constrID )
	self.ConstraintEditor:ShowConstr( codedData, args )

end


function PANEL:RemoveConstr( constrID )

	local editor = self.ConstraintEditor
	if not editor then return end

	local constrData = editor:GetConstrData()
	if constrData and editor.constrID == constrID then
		editor:ShowConstr() -- clear
	end

	local constrNode = self:FindConstrNode( constrID )
	if not constrNode then return end
	local constrTypeNode = constrNode:GetParentNode()

	constrNode:Remove()

	if constrTypeNode:GetChildNodeCount() == 1 then
		self:RemoveConstrType( constrTypeNode:GetText() ) -- using the name as a type is not good
	end

end


function PANEL:FindConstrNode( constrID )

	for _, constrTypeNode in pairs( self.Tree:Root():GetChildNodes() ) do

		for _, constrNode in pairs( constrTypeNode:GetChildNodes() ) do

			if constrNode.constrID == constrID then return constrNode end

		end

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

	self.Tree:SetSelectedItem( constrNode )

end


derma.DefineControl( "DConstraintBrowser", "", PANEL, "DPanel" )