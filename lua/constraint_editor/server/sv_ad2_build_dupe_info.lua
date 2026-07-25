-- Arguments:
--	BuildDupeInfo (table): from advdupe2
--
-- Returns:
--	(table): Table whose keys correspond to the entity's index (1 or 2), and whose
--		values are tables containing keys from this list: (entPos, entAngles, bone, bonePos, boneAngles)
function ConstraintEditor.GetTransformsSavedAtConstrCreation( BuildDupeInfo )

	if not BuildDupeInfo then return nil end

	local entsTransforms = {}

	for i = 1, 2 do

		local entStr = "Ent" .. i
		local entPos, entAngles
		local transforms = {}

		if i == 1 then
			entPos = BuildDupeInfo[entStr .. "Pos"]
		elseif BuildDupeInfo.Ent1Pos and BuildDupeInfo.EntityPos then
			entPos = BuildDupeInfo.Ent1Pos - BuildDupeInfo.EntityPos
		end
		entAngles = BuildDupeInfo[entStr .. "Ang"]

		local foundValuesForEnt = entPos or entAngles

		if foundValuesForEnt then
			transforms.entPos		= entPos
			transforms.entAngles	= entAngles
			entsTransforms[i]		= transforms
		end

		local boneStr	= "Bone" .. i
		local bone		= BuildDupeInfo[boneStr]
		local bonePos, boneAngles

		if bone then
			boneAngles	= BuildDupeInfo[boneStr .. "Angle"]
			bonePos		= BuildDupeInfo[boneStr .. "Pos"] + entPos -- TODO: this should be fine but are there any cases where a pos given for the bone but not for the entity?

			if bonePos or boneAngles then
				transforms.bone			= bone
				transforms.bonePos		= bonePos
				transforms.boneAngles	= boneAngles
				if not foundValuesForEnt then entsTransforms[i] = transforms end
			end

		end

	end

	return ( next( entsTransforms ) ~= nil ) and entsTransforms or nil

end


-- Puts entities back to the position and angles they were in relative to each other upon constraint creation
-- TODO: check why when world is involved, it doesn't always work as intended, and if it can be fixed.
function ConstraintEditor.ApplyTransformsSavedAtConstrCreation( BuildDupeInfo, constrData )

	local entKeys = ConstraintEditor.GetConstrEntKeys( constrData )

	local restoreMats, restoreMotions = {}, {}

	local entsTransforms = ConstraintEditor.GetTransformsSavedAtConstrCreation( BuildDupeInfo ) or {}

	for i, transform in pairs( entsTransforms ) do

		local ent = constrData[entKeys[i]] or constrData[i]
		if IsValid( ent ) then

			restoreMats[ent] = ent:GetWorldTransformMatrix()
			if transform.entPos then ent:SetPos( transform.entPos ) end
			if transform.entAngles then ent:SetAngles( transform.entAngles ) end

			local phys = transform.bone and ent:GetPhysicsObjectNum( transform.bone )
			if IsValid( phys ) then
				restoreMats[phys] = phys:GetPositionMatrix()
				restoreMotions[phys] = phys:IsMotionEnabled()
				phys:EnableMotion( false )
				if transform.bonePos then phys:SetPos( transform.bonePos ) end
				if transform.boneAngles then phys:SetAngles( transform.boneAngles ) end
			end

		end

	end

	return restoreMats, restoreMotions

end



-- Gets the transforms each entity / phys obj should have to recreate the constraint 'identically'
-- We could use BuildDupeInfo directly but this returns a ready-to-use table (obj -> its matrix)
--
-- Returns:
--	mats (table): Table whose keys are entities or phys objs and values are matrices representing the transforms they should have during constraint creation
function ConstraintEditor.GetMatricesFromConstrCreation( BuildDupeInfo, constrData, entKeys )

	if not BuildDupeInfo then return end

	entKeys		= entKeys or ConstraintEditor.GetConstrEntKeys( constrData )
	boneKeys	= boneKeys or ConstraintEditor.GetConstrBoneKeys( constrData )

	local entsTransforms = ConstraintEditor.GetTransformsSavedAtConstrCreation( BuildDupeInfo ) or {}
	local mats			= {}

	for i, entKey in pairs( entKeys ) do

		local ent = constrData[entKey]
		if not ( ent:IsValid() or ent:IsWorld() ) then continue end

		local transforms = entsTransforms[i] or {}

		local entMat = Matrix()
		entMat:SetAngles( transforms.entAngles or ent:GetAngles() )
		entMat:SetTranslation( transforms.entPos or ent:GetPos() )
		mats[ent] = entMat

		if ent:GetPhysicsObjectCount() <= 1 then continue end

		local bone	= transforms.bone or constrData[boneKeys[i]]
		local phys	= bone and ent:GetPhysicsObjectNum( bone )

		if IsValid( phys ) then
			local boneMat = Matrix()
			boneMat:SetAngles( transforms.boneAngles or phys:GetAngles() )
			boneMat:SetTranslation( transforms.bonePos or phys:GetPos() )
			mats[phys] = boneMat
		end

	end

	return mats

end