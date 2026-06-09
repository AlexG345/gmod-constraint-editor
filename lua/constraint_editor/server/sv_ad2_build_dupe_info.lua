-- Calculates the final world transform matrices without moving any entities.
-- Will always return all the bone positions
-- Uses current entities and physobj transforms in case info is missing
-- Returns:
--	matrix1 (VMatrix):
--	matrix2 (VMatrix):
-- local function getMatricesFromConstrCreationTime( BuildDupeInfo, constrData, entKeys )

-- 	if not BuildDupeInfo then return nil end

-- 	entKeys = entKeys or ConstraintEditor.GetConstrEntKeys( constrData )
-- 	local boneKeys

-- 	local mats		= {}

-- 	for i, entKey in pairs( entKeys ) do

-- 		local entStr	= "Ent" .. i
-- 		local ent		= constrData[entKey]
-- 		local entPos, entAngles


-- 		if i == 1 then
-- 			entPos = BuildDupeInfo[entStr .. "Pos"]
-- 		elseif BuildDupeInfo.Ent1Pos and BuildDupeInfo.EntityPos then
-- 			entPos = BuildDupeInfo.Ent1Pos - BuildDupeInfo.EntityPos
-- 		end
-- 		entAngles = BuildDupeInfo[entStr .. "Ang"]

-- 		local foundValuesForEnt		= entAngles or entPos

-- 		if foundValuesForEnt then
-- 			local entMat = Matrix()
-- 			entMat:SetTranslation( entPos or ent:GetPos() )
-- 			entMat:SetAngles( entAngles or ent:GetAngles() )
-- 			mats[i] = { ent = entMat }
-- 		end

-- 		if ent:GetPhysicsObjectCount() <= 1 then continue end

-- 		local boneStr	= "Bone" .. i
-- 		local bone		= BuildDupeInfo[boneStr]
-- 		local bonePos, boneAngles


-- 		if bone then
-- 			-- If the bone has no saved values then it must use the same values as the ent's SAVED ones
-- 			boneAngles	= BuildDupeInfo[boneStr .. "Angle"] or entAngles
-- 			bonePos		= BuildDupeInfo[boneStr .. "Pos"]
-- 			-- If the bone has a saved position then it's relative to the entity
-- 			if bonePos then
-- 				bonePos = bonePos + ( entPos or ent:GetPos() )
-- 			else
-- 				bonePos = entPos
-- 			end
-- 		end

-- 		-- Early stop if we didn't find any saved values for the bone
-- 		if not ( boneAngles or bonePos ) then continue end

-- 		if boneAngles and bonePos then
-- 			local boneMat = Matrix()
-- 			boneMat:SetAngles( boneAngles )
-- 			boneMat:SetTranslation( bonePos )
-- 			mats[i].bone = boneMat
-- 			continue
-- 		end

-- 		-- Must access the physics object to prevent having an incomplete matrix
-- 		if not bone then
-- 			boneKeys		= boneKeys or ConstraintEditor.GetConstrBoneKeys( constrData )
-- 			local boneKey	= boneKeys[i]
-- 			bone			= boneKey and constrData[boneKey]
-- 		end
-- 		if not bone then continue end

-- 		local phys = ent:GetPhysicsObjectNum( constrData[boneKey] )
-- 		if not IsValid( phys ) then continue end

-- 		local boneMat = Matrix()
-- 		boneMat:SetAngles( boneAngles or phys:GetAngles() )
-- 		boneMat:SetTranslation( bonePos or phys:GetPos() )
-- 		mats[i].bone = boneMat

-- 	end

-- 	return mats

-- end


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
			entsTransforms[i] = transforms
		end

		local boneStr	= "Bone" .. i
		local bone		= BuildDupeInfo[boneStr]
		local bonePos, boneAngles

		if bone then
			boneAngles	= BuildDupeInfo[boneStr .. "Angle"]
			bonePos		= BuildDupeInfo[boneStr .. "Pos"] + entPos -- TODO: this should be fine but are there any cases where a pos given for the bone but not for the entity?

			if bonePos or boneAngles then

				if not foundValuesForEnt then entsTransforms[i] = transforms end
				transforms.bone			= bone
				transforms.bonePos		= bonePos
				transforms.boneAngles	= boneAngles
			end

		end

	end

	return ( next( entsTransforms ) ~= nil ) and entsTransforms or nil

end


-- Gets the transforms each entity / phys obj should have to recreate the constraint 'identically'
--
-- Returns:
--	mats (table): Table whose keys are entities or phys objs and values are matrixes representing the transforms they should have during constraint creation
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

		local bone	= transforms.bone or boneKeys[i]
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