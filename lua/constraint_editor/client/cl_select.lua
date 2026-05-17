ConstraintEditor.EditModes = {
	NONE	= 0,
	SINGLE	= 1,
	MANY	= 2
}


local NT = ConstraintEditor.netTags


-- Ask the server to send over the (optionally default) constrData for a constraint.
--
-- Arguments:
--	constrID (int): The constraint creation ID representative of the data we want to get
--	getDefault (boolean): true only if you want to ask for default data
function ConstraintEditor.FillConstrEditor( constrID, getDefault )
	if ConstraintEditor.NetStartWrite( NT.FILL_CONSTR_EDITOR ) then
		ConstraintEditor.NetWriteConstrIDs( { [constrID] = true }, false )
		net.WriteBool( getDefault )
		net.SendToServer()
	end
end


-- Call a selection function on the constraint browser, updates stuff accordingly
-- Arguments:
--	funcName (string): Name of the function to call on the constraint browser
--	...: Arguments to pass to the constraint browser function
function ConstraintEditor.CallSelectFuncOnConstraintBrowser( funcName, ... )

	local constrBrowser = ConstraintEditor.GetConstrBrowser()
	if not constrBrowser then return end

	-- The constraint browser function must return this stuff
	local dataNeeded, IDs, editMode = constrBrowser[funcName]( constrBrowser, ... )
	print( dataNeeded, IDs, editMode )

	if not dataNeeded then return end

	ConstraintEditor.FillConstrEditor( next( IDs ), editMode == ConstraintEditor.EditModes.MANY )

end

-- Select or unselect constraints by their creation IDs, for modification through the menu.
-- Assumes the constraint creation IDs correspond to constraints of the same type.
--
-- Arguments:
--	selection (table): A table whose values are the constraint creation IDs of the constraints that we want to select
--	constrType (string): The constraint type (e.g. Rope, Weld, ...) shared by all the constraints from selection (arg)
--	elimination (table | boolean | nil): Can be:
--		A table whose values are the constraint creation IDs of the constraints that we want to unselect
--		true to clear the selection entirely
function ConstraintEditor.SelectConstrs( selection, constrType, elimination )
	ConstraintEditor.CallSelectFuncOnConstraintBrowser( "SelectIDs", selection, constrType, elimination )
end


-- Arguments:
--	IDsToToggle (table): A table whose values are the constraint creation IDs that we want to toggle
--	selectionDataType (string): The constraint type (e.g. Rope, Weld, ...) shared by the constraints that will end up being toggled on
--	clearSelection (boolean): true to clear the selection entirely
function ConstraintEditor.ToggleConstrs( IDsToToggle, constrType, clearSelection )
	ConstraintEditor.CallSelectFuncOnConstraintBrowser( "ToggleIDs", IDsToToggle, constrType, clearSelection )
end


-- Select an entity, optionally unselecting all previous ones. This impacts which constraints are shown in the constraint browser.
--
-- Arguments:
--	ent (Entity | nil): The entity to select
--	clearSelection (boolean | nil): true only if you want to unselect all constraints beforehand
function ConstraintEditor.SelectEntity( ent, clearSelection )

	if clearSelection then
		ConstraintEditor.NetSend( ConstraintEditor.netTags.CLEAR_ENTITY_SELECTION )
	end

	if ent and ConstraintEditor.NetStartWrite( ConstraintEditor.netTags.SELECT_ENTITY ) then
		net.WriteEntity( ent )
		net.SendToServer()
	end

end


function ConstraintEditor.IgnoreEntity( ent )

	if ent and ConstraintEditor.NetStartWrite( ConstraintEditor.netTags.IGNORE_ENTITY ) then
		net.WriteEntity( ent )
		net.SendToServer()
	end

end


-- Toggle an entity, optionally unselecting all previous ones. This impacts which constraints are shown in the constraint browser.
-- Toggle means that if the entity is selected, it'll be unselected, and vice versa.
--
-- Arguments:
--	ent (Entity | nil): The entity to toggle
--	clearSelection (boolean | nil): true only if you want to unselect all constraints beforehand
function ConstraintEditor.ToggleEntity( ent, clearSelection )

	if clearSelection then
		ConstraintEditor.NetSend( ConstraintEditor.netTags.CLEAR_ENTITY_SELECTION )
	end

	if ent and ConstraintEditor.NetStartWrite( ConstraintEditor.netTags.TOGGLE_ENTITY ) then
		net.WriteEntity( ent )
		net.SendToServer()
	end

end