----------------------------------------------------------
--  Knows wich constraints are selected					--
--  (= which ones the constraint editor is targetting)  --
----------------------------------------------------------


local PANEL = {}


local EM = ConstraintEditor.EditModes


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
		mode		= EM.None
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

	local count = table.Count( t.IDs )
	t.count		= count
	t.editMode	= ( count < 1 and EM.NONE ) or ( count == 1 and EM.SINGLE) or EM.MANY

	return editMode ~= t.editMode

end



-- Prepare for a change in the selected IDs
--
-- Arguments:
--	newIDs (table): A table whose keys are IDs, and whose values should be boolean (true to select, false to unselect)
--	dataType (string): The "type of data" (e.g. Rope, Weld, ...)
--	clearSelection (boolean | nil): true only if you want to unselect all IDs beforehand
--
-- Returns:
--	dataNeeded (boolean | nil): true only if the editor needs fresh data from elsewhere
--	IDs (table | nil): The final selected IDs
--	(int | nil): The final edit mode
function PANEL:SelectIDs( newIDs, dataType, clearSelection )

	local t = self.selectionData

	if clearSelection then
		-- If we clear the current selectionn, no need to check dataType's (arg) consistency with the current one
		self.IDs = {}
	else
		-- TODO: might want to move this check after since it's possible that we're going to disable all current IDs, then enable new ones for a new data type.
		-- (though this would complicates things a lot)
		if ( t.editMode ~= EM.NONE ) and ( dataType ~= t.dataType ) then return end
	end

	t.dataType = dataType or ""

	local IDs = t.IDs

	-- Enable or disable the given IDs
	if newIDs then
		for newID, enabled in pairs( newIDs ) do
			IDs[newID] = enabled or nil
		end
	end

	local editModeChanged = self:UpdateEditMode()

	-- Clear the editor now to prevent the user from (accidentally)
	-- sending current values meant for the old IDs to the new IDs
	if editModeChanged then
		self.constraintEditor:Clear()
	end

	local dataNeeded = modeChanged and t.editMode ~= EM.NONE

	return dataNeeded, IDs, t.editMode

end


function PANEL:ForgetConstr( constrID )

	self:SelectIDs(
		{ [constrID] = false },
		self.selectionData.dataType
	)

	self.constraintTree:ForgetConstr( constrID )

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

	local constrIDs		= self.constrIDs
	local constrData	= self.constraintEditor:GetEditedValues()

	ConstraintEditor.SendToServer(
		NT.UPDATE_CONSTRS,
		{ constrData },
		ConstraintEditor.ToNetConstrIDs( constrIDs )
	)

	-- TODO: add back constraint type selection
	-- ConstraintEditor.SendToServer( NT.UPDATE_TYPE,  { constrData }, { constrData.Type } )

end

derma.DefineControl(
	"DConstraintBrowser",
	"This is from the Constraint Editor addon.",
	PANEL,
	"DPanel"
)