ConstraintEditor = {}

ConstraintEditor.NetTags = {
	ADD_EDITED_ENTITY		= 0,
	CLEAR_EDITED_ENTS		= 1,
	LEFT_CLICK				= 2,
	RIGHT_CLICK				= 3,
	RELOAD					= 4,
	UPDATE_CONSTR			= 5,
	REMOVE_CONSTR			= 6,
	DUPLIC_CONSTR			= 7,
	UPDATE_TYPE				= 8,
	CLEAR_SHOWN_CONSTRS		= 9,
	ADD_SHOWN_CONSTRS		= 10,
	GET_CONSTR_DATA			= 11,
	GET_DEF_CONSTR_DATA		= 12,
	SET_EDITOR_DATA			= 13,
	FORGET_CONSTR			= 14,
	TRANSFER_CONSTR_ENTS	= 15,
	TRANSFER_CONSTRS_ENTS	= 16,
}

ConstraintEditor.NetBitCounts = {
	TAG			= 5,
	CONSTR_ID	= 24, -- creation ids go up to 10 million
}

ConstraintEditor.NetWriteFuncs = {
	[TYPE_STRING]		= net.WriteString,
	[TYPE_NUMBER]		= net.WriteUInt,
	[TYPE_TABLE]		= net.WriteTable,
	[TYPE_BOOL]			= net.WriteBool,
	[TYPE_ENTITY]		= net.WriteEntity,
	[TYPE_VECTOR]		= net.WriteVector,
	[TYPE_ANGLE]		= net.WriteAngle,
	[TYPE_MATRIX]		= net.WriteMatrix,
	[TYPE_COLOR]		= net.WriteColor,
}
