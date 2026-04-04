----------------------------------------------------------
--  Knows wich constraints are selected					--
--  (= which ones the constraint editor is targetting)  --
----------------------------------------------------------


local PANEL = {}


function PANEL:Init()

	self.Divider = self:Add( "DVerticalDivider" )
	self.Divider:Dock( FILL )
	self.Divider:SetTopHeight( 240 )
	self.Divider:SetTopMin( 100 )
	self.Divider:SetBottomMin( 300 )
	self.Divider:SetDividerHeight( 5 )


	self.constraintTree = self.Divider:Add( "DConstraintTree" )
	self.Divider:SetTop( self.constraintTree )

	self.constraintEditor = self.Divider:Add( "DConstraintEditor" )
	self.Divider:SetBottom( self.constraintEditor )

	self.selectionData = {
		dataType	= "",
		IDs			= {},
		count		= 0,
		mode		= ConstraintEditor.EditModes.None
	}

end



function PANEL:Clear()

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
--	IDs (table | nil): The final selected IDs
--	(int | nil): The final edit mode
function PANEL:SelectIDs( selection, selectionDataType, elimination )

	print("dconstraintbrowser select ids", selection, selectionDataType, elimination)

	if not ( selection or elimination ) then return end

	local t = self.selectionData

	if elimination then
		if istable( elimination ) then
			for _, ID in pairs( elimination ) do t.IDs[ID] = nil end
		else
			t.IDs = {}
		end
	end

	if selection then
		selectionDataType = selectionDataType or ""

		-- Update the data type if the browser's selection is empty
		if t.editMode == ConstraintEditor.EditModes.NONE then
			t.dataType = selectionDataType
		end

		-- Select the given IDs if the data type matches
		if t.dataType == selectionDataType then
			for _, ID in pairs( selection ) do t.IDs[ID] = true end
		end
	end

	local editModeChanged = self:UpdateEditMode()

	-- Clear the editor now to prevent the user from accidentally sending current
	-- values meant for the old selection to the (vastly different) new selection
	if editModeChanged then
		self.constraintEditor:Clear()
	end

	local dataNeeded = editModeChanged and t.editMode ~= ConstraintEditor.EditModes.NONE

	return dataNeeded, IDs, t.editMode

end


function PANEL:UnregisterConstrs( constrIDs )

	self:SelectIDs( nil, nil, constrIDs )

	for _, constrID in pairs( constrIDs ) do
		self.constraintTree:UnregisterConstr( constrID )
	end
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

	ConstraintEditor.SendToServer(
		ConstraintEditor.netTags.UPDATE_CONSTRS,
		{ constrData },
		ConstraintEditor.ToNetConstrIDs( constrIDs )
	)

	-- TODO: add back constraint type selection
	-- ConstraintEditor.SendToServer( ConstraintEditor.netTags.UPDATE_TYPE,  { constrData }, { constrData.Type } )

end

derma.DefineControl(
	"DConstraintBrowser",
	"This is from the Constraint Editor addon.",
	PANEL,
	"DPanel"
)