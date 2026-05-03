------------------------------------------------------------
--  Lets you see all constraints available for selection  --
------------------------------------------------------------

local PANEL = {}

function PANEL:Init()

	self.dataPerConstrType = {
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

	local h, s, v	= ColorToHSV( self:GetSkin().Colours.Properties.Column_Selected )
	h = h - 70
	v = v - 0.15
	s = s + 0.5

	self.selectColor = HSVToColor( h, s, v )
	self.selectColor.a = 150

	self.constrNodes = {}

	self.defaultIcon	= "icon16/cog_add.png"

end


function PANEL:ClearVisual()

	local rootNode = self:Root()
	rootNode.ChildNodes = nil
	rootNode:CreateChildNodes()
	return rootNode

end


-- Creates or complete the browser data associated with a constraint type
--
-- Arguments:
--	constrType (string): The constraint type to be added
function PANEL:RegisterConstrType( constrType )

	local t = self.dataPerConstrType

	if not t[constrType] then t[constrType] = {} end

	local data = t[constrType]

	if not IsValid( data.panel ) then
		data.panel = self:AddNode( constrType, data.icon or self.defaultIcon )
		data.panel.constrType = constrType
	end

end


function PANEL:ClearConstrType( constrType, data )

	data = data or self:getDataPerConstrType( constrType )

	if istable( data ) and data.panel then

		for _, constrNode in pairs( data.panel:GetChildNodes() ) do
			if constrNode.constrID then
				self.constrNodes[constrNode.constrID] = nil
			end
		end

		data.panel:Remove()
		data.panel = nil
	end

end


function PANEL:Clear()

	self:ClearVisual()

	for constrType, data in pairs( self.dataPerConstrType ) do
		self:ClearConstrType( constrType, data )
	end

end



function PANEL:SortConstrTypes()

	local rootNode = self:ClearVisual()
	local constrTypes = table.GetKeys( self.dataPerConstrType )
	table.sort( constrTypes )

	for _, constrType in ipairs( constrTypes ) do

		local data = self:getDataPerConstrType( constrType )
		local node = istable( data ) and data.panel

		if node then rootNode.ChildNodes:Add( node ) end

		rootNode:InvalidateChildren() -- call this or the nodes won't show up!

	end

end


function PANEL:AddConstrToNode( constrTypeNode, constrID )

	local node = constrTypeNode:AddNode( ( "[%s]" ):format( constrID ), "icon16/application_view_columns.png" )
	node.constrID = constrID

	function node:ApplySchemeSettings()
		local c = node:GetBackgroundColor()
		if c then
			node:SetBGColor( c )
		end
	end

	return node

end


function PANEL:RegisterConstrs( surfaceConstrsData )

	if not istable( surfaceConstrsData ) then return end

	for constrType, constrsData in pairs( surfaceConstrsData ) do

		local data = self:getDataPerConstrType( constrType, true )
		local node = data.panel

		for constrID, _ in pairs( constrsData ) do
			if not self.constrNodes[constrID] then
				self.constrNodes[constrID] = self:AddConstrToNode( node, constrID )
			end
		end

	end

	self:SortConstrTypes()

end


function PANEL:UnregisterConstr( constrID )

	local constrNode = self:GetConstrNode( constrID )
	self.constrNodes[constrID] = nil

	if not constrNode then return end

	local constrTypeNode = constrNode:GetParentNode()
	constrNode:Remove()

	if constrTypeNode:GetChildNodeCount() <= 1 then
		self:ClearConstrType( constrTypeNode.constrType )
	end

end


-- Gets (and optionally creates/complete) the browser data associated with a constraint type
--
-- Arguments:
--	constrType (string): The constraint type whose associated data we want to get
--	create (boolean): true only if you want to create/complete any missing data for constrType (arg)
--
-- Returns:
--	data (table): A table for the constraint type, contained inside of self.dataPerConstrType:
--		icon (string | nil): An icon representing constrType (arg)
--		panel (DTree_Node | nil): The node associated with constrType (arg)
function PANEL:getDataPerConstrType( constrType, create )

	if not isstring( constrType ) then return false end

	if create then self:RegisterConstrType( constrType ) end

	return self.dataPerConstrType[constrType]

end


function PANEL:DoClick( node )

	local selection = {}
	local constrType
	local clearSelection = not LocalPlayer():KeyDown( IN_SPEED )

	if node.constrID then
		constrType = node:GetParentNode().constrType
		table.insert( selection, node.constrID )
		node:SetSelected( false )
	else
		constrType = node.constrType

		for _, childNode in pairs( node:GetChildNodes() ) do
			if childNode.constrID then
				table.insert( selection, childNode.constrID )
			end
		end
	end

	ConstraintEditor.ToggleConstrs( selection, constrType, clearSelection )


end


function PANEL:GetConstrNode( constrID )

	return self.constrNodes[constrID]

end


function PANEL:GetConstrTypeNode( constrType )

	local t = self.dataPerConstrType[constrType]
	return t and t.panel

end


function PANEL:VisualSelectConstrNode( constrID, enable )

	local constrNode = self:GetConstrNode( constrID )

	if constrNode then
		constrNode:SetPaintBackgroundEnabled( enable )
		constrNode:SetBGColor( self.selectColor )
		constrNode:SetBackgroundColor( enable and self.selectColor or nil )
		if enable then constrNode:ExpandTo( true ) end
	end

end




derma.DefineControl(
	"DConstraintTree",
	"This is from the Constraint Editor addon.",
	PANEL,
	"DTree"
)