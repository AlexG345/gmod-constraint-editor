local PANEL = {}

local NT = ConstraintEditor.NetTags
local EM = ConstraintEditor.EditModes


function PANEL:Init()

	local editor = self

	self.constrArgsCache = {}
	self.constrDataCache = {}

	self.Divider = self:Add( "DVerticalDivider" )
	self.Divider:Dock( FILL )
	self.Divider:SetDividerHeight( 2 )


	self.Properties = self.Divider:Add( "DProperties" )
	self.Divider:SetTop( self.Properties )


	self.DividerList = self.Divider:Add( "DHorizontalDivider" )
	self.Divider:SetBottom( self.DividerList )
	self.DividerList:SetDividerWidth( 1 )

	self.ListButtons1 = self.DividerList:Add( "DListLayout" )
	self.DividerList:SetLeft( self.ListButtons1 )

		local ButtonApply = self.ListButtons1:Add( "DButton" )
		self.ButtonApply = ButtonApply
		ButtonApply:SetImage( "icon16/database_refresh.png" )
		ButtonApply:SetText( "Apply Changes" )

		function ButtonApply:DoClick()
			local constrID = editor.constrID
			local constrData = editor:GetConstrData()
			if constrID then
				ConstraintEditor.SendDataToServer( NT.UPDATE_CONSTR, { constrData }, ConstraintEditor.ToNetConstrIDs( editor.constrIDs ) )
			else
				ConstraintEditor.SendDataToServer( NT.UPDATE_TYPE,  { constrData }, { constrData.Type } )
			end
		end


		local ButtonDuplicate = self.ListButtons1:Add( "DButton" )
		self.ButtonDuplicate = ButtonDuplicate
		ButtonDuplicate:SetImage( "icon16/application_double.png" )
		ButtonDuplicate:SetText( "Duplicate Constraint" )

		function ButtonDuplicate:DoClick()
			ConstraintEditor.SendDataToServer( NT.DUPLIC_CONSTR, ConstraintEditor.ToNetConstrIDs( editor.constrIDs ) )
		end


		local ButtonDelete = self.ListButtons1:Add( "DButton" )
		self.ButtonDelete = ButtonDelete
		ButtonDelete:SetImage( "icon16/database_delete.png" )
		ButtonDelete:SetText( "Remove Constraint" )

		function ButtonDelete:DoClick()
			ConstraintEditor.SendDataToServer( NT.REMOVE_CONSTR, ConstraintEditor.ToNetConstrIDs( editor.constrIDs ) )
		end


	self.ListButtons2 = self.DividerList:Add( "DListLayout" )
	self.DividerList:SetRight( self.ListButtons2 )

		local ButtonCopy = self.ListButtons2:Add( "DButton" )
		self.ButtonCopy = ButtonCopy
		ButtonCopy:SetImage( "icon16/page_copy.png" )
		ButtonCopy:SetText( "Copy all values" )

		function ButtonCopy:DoClick()
			editor:CopyFullData()
			editor.ButtonPaste:SetEnabled( editor:CanPaste() )
		end

		local ButtonPaste = self.ListButtons2:Add( "DButton" )
		self.ButtonPaste = ButtonPaste
		ButtonPaste:SetImage( "icon16/page_paste.png" )
		ButtonPaste:SetText( "Paste all values" )

		function ButtonPaste:DoClick()
			editor:TryApplyData( editor.copiedConstrData )
		end

		ButtonPaste:SetEnabled( false )

	self.typeRestoreFuncs = {
		boolean	= tobool,
		number	= tonumber,
		string	= tostring,
		Vector	= Vector,
		table	= string.ToTable,
		color	= string.ToColor,
	}

	self.copiedConstrData	= {}

	self:ClearSelection()

end


function PANEL:PerformLayout( width, height )

	local buttonHeightTotal = self.ButtonApply:GetTall() * 3
	self.Divider:SetBottomMin( buttonHeightTotal )
	self.Divider:SetTopMin( height - buttonHeightTotal )

	local leftWidth = width / 2

	self.DividerList:SetLeftMin( leftWidth )
	self.DividerList:SetRightMin( width - leftWidth )

	self.Divider:DoConstraints()

end

function PANEL:ClearSelection()

	self.IDs			= {}
	self.editCount		= 0
	self.editMode		= EM.NONE

	self:PrepareForFill()

end


function PANEL:PrepareForFill()

	self.Properties:Clear()
	self.rows = {}

	self.args				= {}
	self.constrData			= {}
	self.constrDataCache	= {}

end


-- whether we're not editing anything, editing a single thing, or editing many things
local function getEditMode( IDCount )
	return ( IDCount < 1 and EM.NONE ) or ( IDCount == 1 and EM.SINGLE) or EM.MANY
end


-- Prepares the editor for a change in the selected IDs
-- Arguments:
--	newIDs (table): A table whose keys are IDs, and whose values should be boolean (true to select, false to unselect)
--	dataType (string): The "type of data" (e.g. Rope, Weld, ...)
--	clearSelection (boolean | nil): true only if you want to unselect all IDs beforehand
--
-- Returns:
--	(boolean | nil): true only if the editor needs fresh data from elsewhere
--	IDs (table | nil): The final selected IDs
--	(int | nil): The final edit mode
function PANEL:ChangeIDsAndPrepare( newIDs, dataType, clearSelection )

	local editMode = self.editMode

	if clearSelection then
		-- In that case no need to check dataType (arg)
		self:ClearSelection()
	else
		-- TODO: might want to move this check after since it's possible that we're going to disable all current IDs, then enable new ones for a new data type.
		-- though this would complicates things a lot
		if editMode ~= EM.NONE and ( dataType ~= self.constrData.Type ) then return end
	end

	if not newIDs then return end

	-- Enable/disable the given IDs
	local IDs = self.IDs
	for newID, enabled in pairs( newIDs ) do
		IDs[newID] = enabled or nil
	end

	self.editCount = table.Count( IDs )

	self.editMode = getEditMode( self.editCount )

	local editModeChanged = editMode ~= self.editMode

	-- Clear the editor now to prevent the user from (accidentally)
	-- sending current values meant for the old IDs to the new IDs
	if editModeChanged then self:PrepareForFill() end

	return editModeChanged and self.editMode ~= EM.NONE, IDs, self.editMode

end





--[[
-- this time without type handling because it's ANNOYING and badly handled everywhere else!!
-- constrData must use integer keys
function PANEL:AddConstr( values, args )

	print("ADD CONSTR")
	if not values then return end
	print("\tvalues found")

	local dataType		= values.Type
	local editMode		= self.editMode
	print("\tdataType vs selfCDType:", dataType, self.constrData.Type)

	-- Don't edit constraints of a different type at once
	if editMode ~= EM.NONE and ( dataType ~= self.constrData.Type ) then return end
	print("\ttype is correct")

	local constrID = values.constrID

	if not constrID then return end
	print("\tconstrID found:", constrID)

	-- TODO: check the line below is correct
	local enableEdit	= values and args and not self.IDs[constrID]
	print("\tenableEdit:", enableEdit)
	self.IDs[constrID]	= enableEdit or nil

	self.editCount	= self.editCount + ( enableEdit and 1 or -1 )
	local newEditMode	= getEditMode( self.editCount )
	print("\tconstrCount:", self.editCount)

	-- No change needed if we're already not editing, or editing the constraint(s) the correct way
	if editMode == newEditMode then return end

	self.editMode = newEditMode
	print("\tnewEditMode:", newEditMode)

	if newEditMode == EM.NONE then
		self:ClearSelection()
	else
		self:Fill( values, args )
	end

end
]]


function PANEL:Fill( values, args )

	print("filling menu")
	self:PrepareForFill()

	self:CreateRows( values, args )

	self:SetRowsValues( values, args, true )

	--[[ TODO: add this back
	if constrType then
		local row = self.Properties:CreateRow( "Extra Information", "Type" )
		row:Setup( "String", { readonly = true } )
		row:SetValue( constrType )
	end

	if self.editCount > 0 then
		local row = self.Properties:CreateRow( "Extra Information", "Constraint Count" )
		row:Setup( "String", { readonly = true } )
		row:SetValue( self.editCount )
	end
	]]

end


function PANEL:CreateRows( values, args )

	self.constrData.Type = values.Type
	self.args = args

	local rowName = self.editMode == EM.SINGLE and "Constraint Properties - Individual edit" or "Constraint Properties - Batch edit"

	for i, arg in ipairs( args ) do

		local value	= values[i]
		local vType	= type( value )
		if vType == "table" and IsColor( value ) then
			vType = "color"
		end

		--print(i,arg,value,vType)

		local typeRestore = self.typeRestoreFuncs[vType]

		local editor = self

		local row = self.Properties:CreateRow( rowName, arg )

			self.rows[i] = row

			row:Setup( vType == "boolean" and "Bool" or "Generic", { readonly = not typeRestore } )

			function row:DataChanged( v ) self:SetValue( v ) end

			--local r, g, b, a = (row:GetSkin().Colours.Properties.Column_Selected or Color(255, 0, 0, 100)):Unpack()
			local r, g, b, a = 140, 220, 100, 100

			function row:SetValue( v, isOriginal, doInner )

				if not isOriginal then v = typeRestore( v ) end
				vString = tostring( v )

				--print("row", v)
				if doInner then row.Inner:SetValue( vString ) end

				local changed = row.cacheString ~= vString

				self:SetBGColor( r, g, b, a )
				self:SetPaintBackgroundEnabled( changed )

				editor.constrData[i] = ( changed or nil ) and v

			end

			--row:SetValue( value, true, true )

			if vType == "Entity" then

				local buttonSwitch = row:Add( "DButton" )

					row.Button = buttonSwitch
					buttonSwitch:SetImage( "icon16/eye.png" )
					buttonSwitch:SetText( "Switch entity" )
					buttonSwitch:DockMargin(0, 1, 1, 1)
					buttonSwitch:Dock(RIGHT)
					local s = row:GetTall()
					buttonSwitch:SetSize( 2 * s, s )
					buttonSwitch:SetTooltip( "Switch this entity to the one you're looking at." )

					function buttonSwitch:DoClick()
						row:SetValue( LocalPlayer():GetEyeTrace().Entity, true, true )
					end

					local oldFunc = row.PerformLayout
					function row:PerformLayout()
						oldFunc( self )
						self.Button:SetWide( self:GetWide() * 0.1 )
					end

			end

	end

	self.ButtonPaste:SetEnabled( self:CanPaste() )

end


function PANEL:SetRowsValues( values, isCache )

	print("SET ROWS VALUES")
	for i, value in pairs( values ) do

		local row = self.rows[i]
		if not row then continue end

		if isCache then row.cacheString = tostring( value ) end

		row:SetValue( value, true, true )

	end

	self.ButtonPaste:SetEnabled( self:CanPaste() )

end


-- tries to apply new data upon existing rows
function PANEL:SafeSetRowsValues( values )

	if not ( values and self.constrData ) then return end

	if values.Type ~= self.constrData.Type then return end

	self:SetRowsValues( values )

end


function PANEL:GetConstrData()

	return self.constrData

end


function PANEL:CanPaste()

	return self.constrData and self.constrData.Type and self.constrData.Type == self.copiedConstrData.Type

end


function PANEL:CopyFullData()

	if not ( self.constrDataCache and self.constrData ) then return end

	table.CopyFromTo( self.constrDataCache, self.copiedConstrData )
	table.Merge( self.copiedConstrData, self.constrData )

end


derma.DefineControl( "DConstraintEditor", "", PANEL, "DPanel" )