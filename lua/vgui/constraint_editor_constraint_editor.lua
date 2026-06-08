-- Prevents having trailing 0s for vectors
-- Not sure how precise vectors are so we keep full float precision even though it is too much
local function getTrimmedVector( vector )

	return string.format( "%f %f %f", vector:Unpack() )

end


local function customToString( value )
	return isvector( value ) and getTrimmedVector( value ) or tostring( value )
end


------------------------------------------------------
--  Lets you edit some properties from constraints
--  Does not change the constraints themselves
------------------------------------------------------


local PANEL = {}


function PANEL:Init()

	local editor = self

	local buttonWidth = 120
	local buttonHeight = buttonWidth / 5

	self.Properties = self:Add( "DProperties" )
	self.Properties:Dock( FILL )

	local tileLayout	= self:Add( "DTileLayout" )
	self.tileLayout		= tileLayout
	tileLayout:Dock( BOTTOM )

		local buttonCopyAll = self.tileLayout:Add( "DButton" )
		buttonCopyAll:SetImage( "icon16/page_white_copy.png" )
		buttonCopyAll:SetText( "Copy all values" )
		buttonCopyAll:SetSize( buttonWidth, buttonHeight )

		function buttonCopyAll:DoClick()
			editor:CopyProperties( editor.editedProperties, editor.cachedProperties )
			editor.buttonPaste:SetEnabled( editor:CanPaste() )
		end

		local buttonCopyEdited = self.tileLayout:Add( "DButton" )
		buttonCopyEdited:SetImage( "icon16/page_copy.png" )
		buttonCopyEdited:SetText( "Copy edited values" )
		buttonCopyEdited:SetSize( buttonWidth, buttonHeight )

		function buttonCopyEdited:DoClick()
			editor:CopyProperties( editor.editedProperties )
			editor.buttonPaste:SetEnabled( editor:CanPaste() )
		end

		local buttonPaste = self.tileLayout:Add( "DButton" )
		self.buttonPaste = buttonPaste
		buttonPaste:SetImage( "icon16/page_paste.png" )
		buttonPaste:SetText( "Paste" )
		buttonPaste:SetSize( buttonWidth, buttonHeight )

		function buttonPaste:DoClick()
			editor:SafeSetProperties( editor.copiedProperties )
		end

		buttonPaste:SetEnabled( false )

		local buttonCache = self.tileLayout:Add( "DButton" )
		buttonCache:SetImage( "icon16/page_refresh.png" )
		buttonCache:SetText( "Reset to cache" )
		buttonCache:SetSize( buttonWidth, buttonHeight )

		function buttonCache:DoClick()
			local b = editor.cacheComparing
			editor:EnableCacheComparing( true )
			editor:SafeSetProperties( editor.cachedProperties )
			editor:EnableCacheComparing( b )
		end

	tileLayout:SetBaseSize( buttonHeight )


	self.typeRestoreFuncs = {
		[TYPE_BOOL]		= tobool,
		[TYPE_NUMBER]	= tonumber,
		[TYPE_STRING]	= tostring,
		-- [TYPE_TABLE]	= string.ToTable,
		[TYPE_ANGLE]	= Angle,
		[TYPE_VECTOR]	= Vector,
		[TYPE_COLOR]	= string.ToColor,
	}

	self.rowTypes = {
		[TYPE_BOOL]		= "Boolean",
		-- Float is not used as it's worse than generic (it keeps trying to limit values to a min and max, feature that i didn't ask for)
		-- it's because it uses a dnumslider internally and those are really annoying when it comes to min/max
		-- [TYPE_NUMBER]	= "Float",

		-- these property editors are all quite useless aren't they?
		[TYPE_COLOR]	= "constraint_editor_color",
	}

	self.copiedProperties = self:GetEmptyProperties()
	self:Clear()

	self:EnableCacheComparing( true )

end


-- function PANEL:PerformLayout( width, height )
-- 	self.vDivider:DoConstraints()
-- 	self.vDivider:SetTopMin(100)
-- end


-- Enable or disable cache comparing. If cache comparing is enabled, values
-- that are the same as the cache are never considered edited, otherwise they
-- are if they've been set one way or another (e.g. by pasting, typing, ...).
--
-- Arguments:
--	enable (boolean): True to enable cache comparing
function PANEL:EnableCacheComparing( enable )
	self.cacheComparing = enable
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

	for i, subValue in pairs( subValues ) do
		if ( type( subValue ) ~= type( values[i] ) ) or ( subArgs[i] ~= args[i] ) then
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
	self.tileLayout:SetVisible( false )

end


-- Creates (initially empty) rows inside of of the editor using a properties table
-- Does not delete already existing rows: you might want to first clear the editor before using this.
--
-- Arguments:
--	properties (table): Table containing:
--		values (table): The properties' values for the rows (should use the same keys as self.rows)
--		args (table): The properties' names for the rows (should use the same keys as self.rows)
--	dataType (string): Text representing what we're editing, only for visual purpose
function PANEL:CreateRows( properties, dataType )

	--local rowName = self.editMode == ConstraintEditor.EditModes.SINGLE and "Constraint Properties - Individual edit" or "Constraint Properties - Batch edit"
	local rowName	= ( dataType or "Constraint" ) .. " Properties"
	local values	= properties.values
	local args		= properties.args

	if next( args ) ~= nil then
		self.tileLayout:SetVisible( true )
	end

	--local colGreen	= Color( 140, 220, 100, 100 )
	--local colGreen	= Color( 200, 120, 60, 255 )
	local function changeHSV( col )
		local h, s, v = ColorToHSV( col )
		return HSVToColor( h - 70, s + 0.5, v - 0.15 )
	end

	local col = changeHSV( self:GetSkin().Colours.Properties.Column_Selected )
	col.a = 150


	for i, arg in ipairs( args ) do

		local rowValue	= values[i]
		local isColor				= IsColor( rowValue )
		local rowType				= isColor and TYPE_COLOR or TypeID( rowValue )
		local rowTypeRestoreFunc	= self.typeRestoreFuncs[rowType]

		local editor = self

		local row = self.Properties:CreateRow( rowName, arg )
		self.rows[i] = row

			row:Setup( self.rowTypes[rowType] or "Generic", { readonly = not rowTypeRestoreFunc } )

			function row:DataChanged( v )
				self:SetValue( v )
			end

			-- TODO: this is not dependant on this element but vectors have less precisions than floats
			-- might be a good idea to forget vectors and use only floats clientside?

			function row:SetValue( newValue, newValueIsProperlyTyped, setInnerValue )

				if not newValueIsProperlyTyped then newValue = rowTypeRestoreFunc( newValue ) end
				local newString = customToString( newValue )

				-- If this is a vector it'll get rounded (to 2 decimals or so iirc) which we don't want.
				-- Using a string works just as good if not better for all non-color values.
				if setInnerValue then row.Inner:SetValue( newString ) end

				-- Better to check for the string instead of the actual value because users input a string...
				local edited = true
				if editor.cacheComparing then
					local cachedValue = editor.cachedProperties.values[i]
					edited = ( customToString( cachedValue ) ~= newString ) or ( cachedValue ~= newValue )
				end

				self:SetPaintBackgroundEnabled( edited )

				if edited then
					-- can be overriden by other stuff otherwise (check wiki pages for these two functions)
					self:SetBGColor( col )
					--self.Label:SetTextColor( color_black )
				end

				editor.editedProperties.values[i]	= ( edited or nil ) and newValue
				editor.editedProperties.args[i]		= ( edited or nil ) and arg

			end

			--row:SetValue( value, true, true )

			local isEntity	= rowType == TYPE_ENTITY
			local isBone	= ( not isEntity ) and ( rowType == TYPE_NUMBER and string.find( arg, "Bone" ) )

			if isEntity or isBone then

				local strings	= isEntity and { "Entity", "entity" } or isBone and { "PhysicsBone", "physics bone" }
				local key, text	= strings[1], strings[2]

				local buttonSwitch = row:Add( "DButton" )

					row.Button = buttonSwitch

					buttonSwitch:SetImage( "icon16/eye.png" )
					buttonSwitch:SetText( "Switch " .. text )
					buttonSwitch:SetTooltip( "Switch this " .. text .. " to the one you're looking at." )

					buttonSwitch:DockMargin(0, 1, 1, 1)
					buttonSwitch:Dock(RIGHT)
					local height = row:GetTall()
					buttonSwitch:SetSize( 2 * height, height )

					function buttonSwitch:DoClick()
						row:SetValue( LocalPlayer():GetEyeTrace()[key], true, true )
					end

					local oldPL = row.PerformLayout
					function row:PerformLayout()
						oldPL( self )
						self.Button:SetWide( self:GetWide() * 0.1 )
					end

			end

	end

	self.buttonPaste:SetEnabled( self:CanPaste() )

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

	local cachedValues	= self.cachedProperties.values
	local cachedArgs	= self.cachedProperties.args

	for i, value in pairs( properties.values ) do

		local row = self.rows[i]
		if not row then continue end

		if setCache then
			cachedValues[i]	= value
			cachedArgs[i]	= properties.args[i]
		end

		row:SetValue( value, true, true )

	end

	self.buttonPaste:SetEnabled( self:CanPaste() )

end


-- Deletes all rows, edited and cached properties, then creates and fills rows using given properties
--
-- Arguments:
--	properties (table): Table containing:
--		values (table): The properties' values for the rows
--		args (table): The properties' names for the rows
--	dataType (string): Text representing what we're editing, only for visual purpose
function PANEL:Fill( properties, dataType )

	self:Clear()

	self:CreateRows( properties, dataType )

	local b = self.cacheComparing
	self:EnableCacheComparing( true )

	self:SetProperties( properties, true )

	self:EnableCacheComparing( b )

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


function PANEL:CopyProperties( priorityProp, modelProp )

	-- this is bad but it works
	modelProp = modelProp or priorityProp

	self.copiedProperties = self:GetEmptyProperties()

	local priorityVals	= priorityProp.values
	local modelVals		= modelProp.values

	local copiedArgs, copiedVals = self.copiedProperties.args, self.copiedProperties.values

	for i, arg in pairs( modelProp.args ) do

		local v = priorityVals[i]
		if v == nil then v = modelVals[i] end

		copiedArgs[i] = arg
		copiedVals[i] = v

	end

end


derma.DefineControl(
	-- it's written twice but it's not a typo
	"constraint_editor_constraint_editor",
	ConstraintEditor.dermaDesc or "",
	PANEL,
	"DPanel"
)
