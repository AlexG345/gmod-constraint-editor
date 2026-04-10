ConstraintEditor.EditModes = {
	NONE	= 0,
	SINGLE	= 1,
	MANY	= 2
}


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

	local constrBrowser = ConstraintEditor.GetConstrBrowser()
	if not constrBrowser then return end

	local dataNeeded, IDs, editMode = constrBrowser:SelectIDs( selection, constrType, elimination )

	if not dataNeeded then return end

	ConstraintEditor.FillConstrEditor( next( IDs ), editMode == ConstraintEditor.EditModes.MANY )

end


-- Arguments:
--	IDsToToggle (table): A table whose values are the constraint creation IDs that we want to toggle
--	selectionDataType (string): The constraint type (e.g. Rope, Weld, ...) shared by the constraints that will end up being toggled on
--	clearSelection (boolean): true to clear the selection entirely
function ConstraintEditor.ToggleConstrs( IDsToToggle, constrType, clearSelection )

	local constrBrowser = ConstraintEditor.GetConstrBrowser()
	if not constrBrowser then return end

	local dataNeeded, IDs, editMode = constrBrowser:ToggleIDs( IDsToToggle, constrType, clearSelection )

	if not dataNeeded then return end

	ConstraintEditor.FillConstrEditor( next( IDs ), editMode == ConstraintEditor.EditModes.MANY )
end


-- Select an entity, optionally unselecting all previous ones. This impacts which constraints are shown in the constraint browser.
--
-- Arguments:
--	ent (Entity | nil): The entity to select
--	clearSelection (boolean | nil): true only if you want to unselect all constraints beforehand
function ConstraintEditor.SelectEntity( ent, clearSelection )

	if clearSelection then
		ConstraintEditor.NetSend(
			ConstraintEditor.netTags.CLEAR_ENTITY_SELECTION
		)
	end

	if ent then
		ConstraintEditor.NetSend(
			ConstraintEditor.netTags.SELECT_ENTITY,
			{ ent }
		)
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
		ConstraintEditor.SelectEntity( ent, true )
		return
	end

	if ent then
		ConstraintEditor.NetSend(
			ConstraintEditor.netTags.TOGGLE_ENTITY,
			{ ent }
		)
	end

end