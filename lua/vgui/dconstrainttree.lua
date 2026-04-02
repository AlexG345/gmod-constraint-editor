------------------------------------------------------------
--  Lets you see all constraints available for selection  --
------------------------------------------------------------

local PANEL = {}

function PANEL:Init()

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

	local t = self.DataPerConstrType

	if not t[constrType] then t[constrType] = {} end
	if not t.constrNodes then t.constrNodes = {} end

	local data = t[constrType]

	if not IsValid( data.panel ) then
		data.panel = self:AddNode( constrType, data.icon or self.defaultIcon )
		data.panel.constrType = constrType
	end

end


function PANEL:ClearConstrType( constrType, data )

	data = data or self:GetDataPerConstrType( constrType )

	if istable( data ) and data.panel then
		data.panel:Remove()
		data.panel = nil
		data.constrNodes = nil
	end

end


function PANEL:Clear()

	self:ClearVisual()

	for constrType, data in pairs( self.DataPerConstrType ) do
		self:ClearConstrType( constrType, data )
	end

end



function PANEL:SortConstrTypes()

	local rootNode = self:ClearVisual()
	local constrTypes = table.GetKeys( self.DataPerConstrType )
	table.sort( constrTypes )

	for _, constrType in ipairs( constrTypes ) do

		local data = self:GetDataPerConstrType( constrType )
		local node = istable( data ) and data.panel

		if node then rootNode.ChildNodes:Add( node ) end

		rootNode:InvalidateChildren() -- call this or the nodes won't show up!

	end

end


function PANEL:AddConstrToNode( constrTypeNode, constrID )

	local node = constrTypeNode:AddNode( ( "[%s]" ):format( constrID ), "icon16/application_view_columns.png" )
	node.constrID = constrID
	return node

end


function PANEL:RegisterConstrs( surfaceConstrsData )

	if not istable( surfaceConstrsData ) then return end

	for constrType, constrsData in pairs( surfaceConstrsData ) do

		local data = self:GetDataPerConstrType( constrType, true )
		local node = data.panel

		for constrID, _ in pairs( constrsData ) do
			if not data.constrNodes[constrID] then
				data.constrNodes[constrID] = self:AddConstrToNode( node, constrID )
			end
		end

	end

	self:SortConstrTypes()

end


-- Gets (and optionally creates/complete) the browser data associated with a constraint type
--
-- Arguments:
--	constrType (string): The constraint type whose associated data we want to get
--	create (boolean): true only if you want to create/complete any missing data for constrType (arg)
--
-- Returns:
--	data (table): A table for the constraint type, contained inside of self.DataPerConstrType:
--		icon (string | nil): An icon representing constrType (arg)
--		panel (DTree_Node | nil): The node associated with constrType (arg)
function PANEL:GetDataPerConstrType( constrType, create )

	if not isstring( constrType ) then return false end

	if create then self:RegisterConstrType( constrType ) end

	return self.DataPerConstrType[constrType]

end


function PANEL:DoClick( node )

	local constrIDs = {}
	local constrType
	local clearSelection = true -- TODO: add SHIFT behavior to select multiple constrs

	if node.constrID then
		constrType = node:GetParentNode().constrType
		constrIDs = { [node.constrID] = true } -- TODO: allow unselect
	else
		constrType = node.constrType

		for _, childNode in pairs( node:GetChildNodes() ) do
			if childNode.constrID then
				constrIDs[childNode.constrID] = true
			end
		end
	end

	ConstraintEditor.SelectConstrs( constrIDs, constrType, clearSelection )

end


function PANEL:ForgetConstr( constrID )

	local constrNode, constrNodes, constrType = self:GetConstrNode( constrID )
	if not constrNode then return end

	constrNodes[constrID] = nil
	local constrTypeNode = constrNode:GetParentNode()
	constrNode:Remove()

	if constrTypeNode:GetChildNodeCount() <= 1 then
		self:ClearConstrType( constrType )
	end

end



function PANEL:GetConstrTypeNode( constrType )

	local t = self.DataPerConstrType[constrType]
	return t and t.panel

end


function PANEL:GetConstrNode( constrID )

	for constrType, data in pairs( self.DataPerConstrType ) do

		local constrNodes = data.constrNodes
		local constrNode = constrNodes and constrNodes[constrID]
		if constrNode then return constrNode, constrNodes, constrType end

	end

end


function PANEL:SelectTypeNode( constrType )

	local constrTypeNode = self:GetConstrTypeNode( constrType )
	if not constrTypeNode then return end

	--constrTypeNode:ExpandTo( true )

	self:SetSelectedItem( constrTypeNode )

end


-- adding constrType lets you force the browser to add a constraint node
function PANEL:SelectConstrNode( constrID, constrType )

	local constrNode = self:GetConstrNode( constrID )
	if constrType and not constrNode then
		self:RegisterConstrs( { [constrType] = { constrID } } )
		constrNode = self:GetConstrNode( constrID )
	end

	if not constrNode then return end

	constrNode:ExpandTo( true )

	self:SetSelectedItem( constrNode )

end




derma.DefineControl(
	"DConstraintTree",
	"This is from the Constraint Editor addon.",
	PANEL,
	"DTree"
)