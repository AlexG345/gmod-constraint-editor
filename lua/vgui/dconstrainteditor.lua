----------------------------
--  Lets you edit values  --
----------------------------


local PANEL = {}


local NT = ConstraintEditor.netTags
local EM = ConstraintEditor.EditModes

------------------------------------------------------------------------------------------------------------------
-- TODO-NEXT:	Move "server" action buttons to the constraint browser??										--
--				.	The constraint tree would let you select constraints: it should just be a 'visualizer'.		--
--				.	The constraint editor would handle constraint properties (modifying, copying, pasting...).	--
--				.	The constraint browser would be able to tell the server to change the constraints selected	--
--					using the tree, with the data from the constraint editor.									--
--					It would be a kind of link between the two other menus and the server itself				--
------------------------------------------------------------------------------------------------------------------

function PANEL:Init()

	local editor = self

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

		-- TODO: this is VERY outdated
		function ButtonApply:DoClick()
			--[[
			local constrID = editor.constrID
			local constrData = editor:GetConstrData()
			if constrID then
				ConstraintEditor.SendToServer( NT.UPDATE_CONSTRS, { constrData }, ConstraintEditor.ToNetConstrIDs( editor.constrIDs ) )
			else
				ConstraintEditor.SendToServer( NT.UPDATE_TYPE,  { constrData }, { constrData.Type } )
			end
			]]
		end


		local ButtonDuplicate = self.ListButtons1:Add( "DButton" )
		self.ButtonDuplicate = ButtonDuplicate
		ButtonDuplicate:SetImage( "icon16/application_double.png" )
		ButtonDuplicate:SetText( "Duplicate Constraint" )

		-- TODO: this is outdated
		function ButtonDuplicate:DoClick()
			--[[
			ConstraintEditor.SendToServer( NT.DUPLIC_CONSTRS, ConstraintEditor.ToNetConstrIDs( editor.constrIDs ) )
			]]
		end


		local ButtonDelete = self.ListButtons1:Add( "DButton" )
		self.ButtonDelete = ButtonDelete
		ButtonDelete:SetImage( "icon16/database_delete.png" )
		ButtonDelete:SetText( "Remove Constraint" )

		-- TODO: this is outdated
		function ButtonDelete:DoClick()
			--[[
			ConstraintEditor.SendToServer( NT.REMOVE_CONSTRS, ConstraintEditor.ToNetConstrIDs( editor.constrIDs ) )
			]]
		end


	self.ListButtons2 = self.DividerList:Add( "DListLayout" )
	self.DividerList:SetRight( self.ListButtons2 )

		local ButtonCopy = self.ListButtons2:Add( "DButton" )
		self.ButtonCopy = ButtonCopy
		ButtonCopy:SetImage( "icon16/page_copy.png" )
		ButtonCopy:SetText( "Copy all values" )

		function ButtonCopy:DoClick()
			editor:CopyFullProperties()
			editor.ButtonPaste:SetEnabled( editor:CanPaste() )
		end

		local ButtonPaste = self.ListButtons2:Add( "DButton" )
		self.ButtonPaste = ButtonPaste
		ButtonPaste:SetImage( "icon16/page_paste.png" )
		ButtonPaste:SetText( "Paste all values" )

		function ButtonPaste:DoClick()
			editor:SafeSetProperties( editor.copiedProperties )
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

	self.copiedProperties = self:GetEmptyProperties()
	self:Clear()

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


-- Gives the simplest properties possible
--
-- Returns:
--	(table): Table containing:
--		values (table): Empty table for the properties' values
--		args (table): Empty table for the properties' names
function PANEL:GetEmptyProperties()
	return { values = {}, args = {} }
end


-- Checks whether the given properties from the editor is a subset of other such properties
-- without checking their values themselves: only their type and name. They must have the same order too.
--
-- Arguments:
--	source (table): Table containing:
--		values (table): The properties' values
--		args (table): The properties' names
--	dest (table): Table with the same structure as source (arg)
function PANEL:PropertiesAreSubset( subProperties, properties )

	local subValues, subArgs	= subProperties.values, subProperties.args
	local values, args			= properties.values, properties.args

	for i, v in pairs( subValues ) do
		if type( subValues[i] ) ~= type( values[i] ) or subArgs[i] ~= args[i] then
			return false
		end
	end

	return true

end



function PANEL:Clear()

	self.Properties:Clear()
	self.rows = {}

	self.cachedProperties = self:GetEmptyProperties()
	self.editedProperties = self:GetEmptyProperties()

end


-- Creates (initially empty) rows inside of of the editor using a properties table
-- Does not delete already existing rows: you might want to first clear the editor before using this.
--
-- Arguments:
--	properties (table): Table containing:
--		values (table): The properties' values for the rows (should use the same keys as self.rows)
--		args (table): The properties' names for the rows (should use the same keys as self.rows)
function PANEL:CreateRows( properties )

	--local rowName = self.editMode == ConstraintEditor.EditModes.SINGLE and "Constraint Properties - Individual edit" or "Constraint Properties - Batch edit"
	local rowName	= "Constraint Properties"
	local values	= properties.values
	local args		= properties.args

	for i, arg in ipairs( args ) do

		local rowValue	= values[i]
		local rowType	= IsColor( rowValue ) and "color" or type( rowValue )
		local rowTypeRestoreFunc = self.typeRestoreFuncs[rowType]

		--print(i,arg,value,rowType)

		local editor = self

		local row = self.Properties:CreateRow( rowName, arg )

			self.rows[i] = row

			row:Setup( isbool( rowValue ) and "Bool" or "Generic", { readonly = not rowTypeRestoreFunc } )

			function row:DataChanged( v ) self:SetValue( v ) end

			--local r, g, b, a = (row:GetSkin().Colours.Properties.Column_Selected or Color(255, 0, 0, 100)):Unpack()
			local r, g, b, a = 140, 220, 100, 100

			function row:SetValue( newValue, newValueIsProperlyTyped, setInnerValue )

				if not newValueIsProperlyTyped then newValue = typeRestore( newValue ) end
				newString = tostring( newValue )

				--print("row", v)
				if setInnerValue then row.Inner:SetValue( newString ) end

				-- Better to check for the string instead of the actual value because users input a string...
				local changed = tostring( editor.cachedProperties.values[i] ~= newString )

				self:SetBGColor( r, g, b, a )
				self:SetPaintBackgroundEnabled( changed )

				editor.editedProperties.values[i] = ( changed or nil ) and v

			end

			--row:SetValue( value, true, true )

			if rowType == "Entity" then

				local buttonSwitch = row:Add( "DButton" )

					row.Button = buttonSwitch

					buttonSwitch:SetImage( "icon16/eye.png" )
					buttonSwitch:SetText( "Switch entity" )
					buttonSwitch:SetTooltip( "Switch this entity to the one you're looking at." )

					buttonSwitch:DockMargin(0, 1, 1, 1)
					buttonSwitch:Dock(RIGHT)
					local s = row:GetTall()
					buttonSwitch:SetSize( 2 * s, s )

					function buttonSwitch:DoClick()
						row:SetValue( LocalPlayer():GetEyeTrace().Entity, true, true )
					end

					local oldPL = row.PerformLayout
					function row:PerformLayout()
						oldPL( self )
						self.Button:SetWide( self:GetWide() * 0.1 )
					end

			end

	end

	self.ButtonPaste:SetEnabled( self:CanPaste() )

end


-- Forcefully replaces the properties of some existing rows (and optionally the editor's cached properties)
--
-- Arguments:
--	properties (table): Table containing:
--		values (table): The properties' values for the rows (should use the same keys as self.rows)
--		args (table): The properties' names for the rows (should use the same keys as self.rows)
--	setCache (boolean): true only to replace the editor's cached properties with properties (arg)
function PANEL:SetProperties( properties, setCache )

	if setCache then self.cachedProperties.type = properties.type end

	local values = properties.values
	local cachedValues = self.cachedProperties.values

	for i, value in pairs( values ) do

		local row = self.rows[i]
		if not row then continue end

		if setCache then cachedValues[i] = value end

		row:SetValue( value, true, true )

	end

	self.ButtonPaste:SetEnabled( self:CanPaste() )

end


-- Deletes all rows, edited and cached properties, then creates and fills rows using given properties
--
-- Arguments:
--	properties (table): Table containing:
--		values (table): The properties' values for the rows
--		args (table): The properties' names for the rows
function PANEL:Fill( properties )

	self:Clear()

	self:CreateRows( properties )

	self:SetProperties( properties, true )

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


-- Replaces the properties values of some existing rows, only if given properties are a subset of the editor cached properties.
--
-- Arguments:
--	properties (table): Table containing:
--		values (table): The properties' values for the rows (should use the same keys as self.rows)
--		args (table): The properties' names for the rows (should use the same keys as self.rows)
function PANEL:SafeSetProperties( properties )

	if not ( properties and self.rows and self:PropertiesAreSubset( properties, self.cachedProperties ) ) then return end

	self:SetProperties( properties )

end



function PANEL:GetEditedValues()

	return self.editedProperties.values

end


function PANEL:CanPaste()

	return self:PropertiesAreSubset( self.copiedProperties, self.cachedProperties )

end


function PANEL:CopyFullProperties()

	-- Copy all cached properties
	table.CopyFromTo( self.cachedProperties, self.copiedProperties )

	-- Override with edited properties
	table.Merge( self.copiedProperties, self.editedProperties )

end


derma.DefineControl(
	"DConstraintEditor",
	"This is from the Constraint Editor addon.",
	PANEL,
	"DPanel"
)