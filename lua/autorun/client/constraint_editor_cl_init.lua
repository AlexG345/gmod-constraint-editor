local NT = ConstraintEditor.NetTags


ConstraintEditor.Constrs = {}
ConstraintEditor.HoveredConstrInfo = { ID = -1, Type = "" } -- for the stool

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


-- Select an entity, optionally unselecting all previous ones. This impacts which constraints are shown in the constraint browser.
--
-- Arguments:
--	ent (Entity | nil): The entity to select
--	clearSelection (boolean | nil): true only if you want to unselect all constraints beforehand
function ConstraintEditor.SelectEntity( ent, clearSelection )

	if clearSelection then
		ConstraintEditor.SendToServer(
			NT.CLEAR_ENTITY_SELECTION
		)
	end

	if ent then
		ConstraintEditor.SendToServer(
			NT.SELECT_ENTITY,
			{ ent }
		)
	end

end


-- Select or unselect constraints by their creation IDs, for modification through the menu.
-- Assumes the constraint creation IDs correspond to constraints of the same type.
--
-- Arguments:
--	constrIDs (table): A table whose keys are constraint creation IDs, and whose values should be boolean (true to enable edit, false to disable)
--	constrType (string): The shared type of constraint (e.g. Rope, Weld, ...)
--	clearSelection (boolean | nil): true only if you want to unselect all constraints beforehand
function ConstraintEditor.SelectConstrs( constrIDs, constrType, clearSelection )

	local constrBrowser = ConstraintEditor.GetConstrBrowser()
	if not constrBrowser then return end

	local dataNeeded, IDs, editMode = constrBrowser.SelectIDs( constrIDs, constrType, clearSelection )

	if not dataNeeded then return end

	ConstraintEditor.GetDataForEditor( next( IDs )[1], editMode == ConstraintEditor.EditModes.MANY )

end


-- Ask the server to send over the (optionally default) constrData for some constraint(s) by a creation ID
--
-- Arguments:
--	constrID (int): The constraint creation ID representative of the data we want to get
--	getDefault (boolean): true only if you want to ask for default data
function ConstraintEditor.GetDataForEditor( constrID, getDefault )

	ConstraintEditor.SendToServer(
		NT.GET_DATA_FOR_EDITOR,
		ConstraintEditor.ToNetConstrID( constrID ),
		getDefault
	)

end


-- Register constraints so that they become visible and editable in the HUD and menu.
--
-- Arguments:
--	surfaceConstrsData (table): Table from the server, it should look like this:
--		{
--			[constrType_1] = {
--				[constrID_1] = {
--					firstEntity, secondEntity, firstLocalPos, secondLocalPos, worldPos_1, worldPos_2, localAxis
--				},
--				etc...
--			},
--			etc...
--		}
function ConstraintEditor.RegisterConstrs( surfaceConstrsData )

	local constrBrowser	= ConstraintEditor.GetConstrBrowser()
	if IsValid( constrBrowser ) then constrBrowser:RegisterConstrs( surfaceConstrsData ) end

	table.Merge( ConstraintEditor.Constrs, surfaceConstrsData )

end



function ConstraintEditor.ForgetConstr( constrID )

	local constrBrowser	= ConstraintEditor.GetConstrBrowser()

	if IsValid( constrBrowser ) then
		constrBrowser:ForgetConstr( constrID )
	end

	for constrType, constrDatas in pairs( ConstraintEditor.Constrs ) do
		constrDatas[constrID] = nil
	end

end


function ConstraintEditor.SendToServer( tag, ... )

	ConstraintEditor.NetStartWrite( tag, ... )

	net.SendToServer()

end
