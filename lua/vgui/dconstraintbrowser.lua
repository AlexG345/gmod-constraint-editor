----------------------------------------------------------
--  Knows wich constraints are selected					--
--  (= which ones the constraint editor is targetting)  --
----------------------------------------------------------


local NT = ConstraintEditor.netTags


local PANEL = {}


function PANEL:Init()

	local constrBrowser = self

	local buttonWidth = 140
	local buttonHeight = buttonWidth / 5

	local hDivider = self:Add( "DHorizontalDivider" )
	hDivider:SetDividerWidth( 5 )
	hDivider:Dock( FILL )

	hDivider:SetLeftMin( 105 )

		local constraintTree = hDivider:Add( "DConstraintTree" )
		hDivider:SetLeft( constraintTree )
		self.constraintTree = constraintTree

		local constraintEditor = hDivider:Add( "DConstraintEditor" )
		hDivider:SetRight( constraintEditor )
		self.constraintEditor = constraintEditor

	local tileLayout	= self:Add( "DTileLayout" )
	self.tileLayout	= tileLayout
	tileLayout:Dock( BOTTOM )

		local buttonApply	= tileLayout:Add( "DButton" )

		buttonApply:SetImage( "icon16/table_go.png"  )
		buttonApply:SetText( "Update Constraints" )
		buttonApply:SetSize( buttonWidth, buttonHeight )

		function buttonApply:DoClick()
			constrBrowser:UpdateServer()
		end


		local buttonDuplicate	= tileLayout:Add( "DButton")

		buttonDuplicate:SetImage( "icon16/table_multiple.png" )
		buttonDuplicate:SetText( "Duplicate Constraints" )
		buttonDuplicate:SetSize( buttonWidth, buttonHeight )

		function buttonDuplicate:DoClick()
			if ConstraintEditor.NetStartWrite( NT.DUPLIC_CONSTRS ) then
				ConstraintEditor.NetWriteConstrIDs( constrBrowser.selectionData.IDs )
				net.SendToServer()
			end
		end


		local buttonDelete	= tileLayout:Add( "DButton" )

		buttonDelete:SetImage( "icon16/table_delete.png" )
		buttonDelete:SetText( "Delete Constraints" )
		buttonDelete:SetSize( buttonWidth, buttonHeight )

		function buttonDelete:DoClick()
			if ConstraintEditor.NetStartWrite( NT.REMOVE_CONSTRS ) then
				ConstraintEditor.NetWriteConstrIDs( constrBrowser.selectionData.IDs )
				net.SendToServer()
			end
		end

	tileLayout:SetBaseSize( buttonHeight )

	-- This uses the width of one of the constraint editor's buttons
	hDivider:SetRightMin( self.constraintEditor.tileLayout:GetChild(1):GetWide() )

	-- self.vDivider:SetBottomMin( buttonHeight * #self.tileLayout:GetChildren() )
	-- self:SetTall( self.vDivider:GetTopMin() + self.vDivider:GetBottomMin() + 100 )
	self:SetTall( 400 )


	self.selectionData = {
		dataType	= "",
		IDs			= {},
		count		= 0,
		mode		= ConstraintEditor.EditModes.None
	}

end


function PANEL:Clear()
	self.selectionData.dataType = ""
	self:SelectIDs( nil, nil, true )

	self.constraintTree:Clear()

	self.constraintEditor:Clear()
end


-- Counts and saves how many IDs are currently selected, updates the edit mode accordingly
--
-- Returns:
--	(boolean) true only if the selection data's edit mode has changed
function PANEL:UpdateEditMode()

	local t = self.selectionData

	local editMode = t.editMode
	local EM = ConstraintEditor.EditModes

	local count = table.Count( t.IDs )
	t.count		= count
	t.editMode	= ( count < 1 and EM.NONE ) or ( count == 1 and EM.SINGLE) or EM.MANY

	return editMode ~= t.editMode

end


-- Prepare for a change in the selected IDs
--
-- Arguments:
--	selection (table | nil): A table whose values are the IDs that we want to add to the selection
--	selectionDataType (string): The "type of data" (e.g. Rope, Weld, ...) of the IDs from selection (arg)
--	elimination (table | boolean | nil): Can be:
--		A table whose values are the IDs that we want to  remove from the selection
--		true to clear the selection entirely
--
-- Returns:
--	dataNeeded (boolean | nil): true only if the editor needs fresh data from elsewhere
--	(table | nil): The final selected IDs
--	(int | nil): The final edit mode
function PANEL:SelectIDs( selection, selectionDataType, elimination )

	print("dconstraintbrowser select ids", selection, selectionDataType, elimination)

	if not ( selection or elimination ) then return end

	local t = self.selectionData
	local IDs = t.IDs

	local oldFirstID = next( IDs )
	local oldSelectionDataType = t.dataType

	if elimination then
		if istable( elimination ) then
			for _, ID in pairs( elimination ) do
				IDs[ID] = nil
				self.constraintTree:VisualSelectConstrNode( ID, false )
			end
		else
			for ID, _ in pairs( IDs ) do
				IDs[ID] = nil
				self.constraintTree:VisualSelectConstrNode( ID, false )
			end
		end
	end

	if selection then
		selectionDataType = selectionDataType or ""

		-- Update the data type if the browser's selection is empty
		if next( IDs ) == nil then
			t.dataType = selectionDataType
		end

		-- Select the given IDs if the data type matches
		if t.dataType == selectionDataType then
			for _, ID in pairs( selection ) do
				IDs[ID] = true
				self.constraintTree:VisualSelectConstrNode( ID, true )
			end
		end
	end

	local EM = ConstraintEditor.EditModes
	local editModeChanged = self:UpdateEditMode()

	-- Clear the editor now to prevent the user from accidentally sending current
	-- values meant for the old selection to the (vastly different) new selection
	if editModeChanged then
		self.constraintEditor:Clear()
		self.constraintEditor:EnableCacheComparing( t.editMode ~= EM.MANY )
	end

	local editingSomething = t.editMode ~= EM.NONE

	-- Either:
	-- We passed from batch mode to single mode, or vice versa
	-- We stayed in single mode but we're not editing the same thing (because different ID)

	local dataNeeded = editingSomething and (
		editModeChanged or (
			( t.editMode == EM.SINGLE ) and
			( oldFirstID ~= next( IDs ) )
		) or (
			( t.editMode == EM.MANY ) and
			( oldSelectionDataType ~= t.dataType )
		)
	)
	print( "dataNeeded:", dataNeeded)

	return dataNeeded, t.IDs, t.editMode

end


-- Prepare for a change in the selected IDs after toggling on/off some of them
--
-- Arguments:
--	IDsToToggle (table): A table whose values are the IDs that we want to toggle
--	selectionDataType (string): The "type of data" (e.g. Rope, Weld, ...) of the IDs from IDsToToggle (arg) that will end up being toggled on
--	clearSelection (boolean): true to clear the selection entirely
--
-- Returns:
--	dataNeeded (boolean | nil): true only if the editor needs fresh data from elsewhere
--	(table | nil): The final selected IDs
--	(int | nil): The final edit mode
function PANEL:ToggleIDs( IDsToToggle, selectionDataType, clearSelection )

	if clearSelection then
		return self:SelectIDs( IDsToToggle, selectionDataType, true )
	end

	local alreadyInIDS = {
		 [false] = {},
		 [true] = {}
	}

	local IDs = self.selectionData.IDs

	for _, constrID in pairs( IDsToToggle ) do
		table.insert(
			alreadyInIDS[( IDs[constrID] and true ) or false],
			constrID
		)
	end

	return self:SelectIDs( alreadyInIDS[false], selectionDataType, alreadyInIDS[true] )
end


function PANEL:UnregisterConstrs( constrIDs )

	local t = { self:SelectIDs( nil, nil, constrIDs ) }

	self.constraintTree:UnregisterConstrs( constrIDs )

	return unpack( t )

end


-- Register constraints so that they become visible and editable in the browser.
--
-- Arguments:
--	surfaceConstrsData (table): Table from the server, it should look like this:
--		{
--			[constrType_1] = {
--				[constrID_1] = _
--				etc...
--			},
--			etc...
--		}
function PANEL:RegisterConstrs( surfaceConstrsData )
	self.constraintTree:RegisterConstrs( surfaceConstrsData )
end


function PANEL:UpdateServer()

	local constrIDs		= self.selectionData.IDs
	local constrData	= self.constraintEditor:GetEditedValues()

	if ConstraintEditor.NetStartWrite( NT.UPDATE_CONSTRS ) then
		-- constrData is not sequential because edited values can skip indexes (e.g. the user only edited the properties of id 1 and 4)
		ConstraintEditor.NetWriteTable( constrData )
		ConstraintEditor.NetWriteConstrIDs( constrIDs )
		net.SendToServer()
	end

end

derma.DefineControl(
	"DConstraintBrowser",
	"This is from the Constraint Editor addon.",
	PANEL,
	"DPanel"
)
