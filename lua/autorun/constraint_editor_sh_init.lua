ConstraintEditor = {}


local function AddFile( dirPath, fileName )

	local fileSide	= string.lower( string.Left( fileName, 3 ) )
	local filePath	= dirPath .. fileName

	local isForBoth		= fileSide == "sh_"
	local isForServer	= isForBoth or fileSide == "sv_"
	local isForClient	= isForBoth or fileSide == "cl_"

	if ( SERVER and isForServer ) or ( CLIENT and isForClient ) then include( filePath ) end

	if SERVER and isForClient then AddCSLuaFile( filePath ) end

end


local function AddDir( dirPath )

	dirPath = dirPath .. "/"
	local files, dirs = file.Find( dirPath .. "*", "LUA")

	for _, fileName in ipairs( files ) do
		if string.EndsWith( fileName, ".lua" ) then
			AddFile( dirPath, fileName )
		end
	end

	for _, dirName in ipairs( dirs ) do
		AddDir( dirPath .. dirName )
	end

end


AddDir( "constraint_editor" )