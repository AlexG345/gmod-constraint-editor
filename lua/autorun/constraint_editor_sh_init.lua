ConstraintEditor = {}

ConstraintEditor.NetTags = {
	CLEAR_EDITED_ENTS		= 0,
	ADD_EDITED_ENTITY		= 1,
	LEFT_CLICK				= 2,
	RIGHT_CLICK				= 3,
	RELOAD					= 4,
	UPDATE_CONSTR			= 5,
	REMOVE_CONSTR			= 6,
	DUPLIC_CONSTR			= 7,
	UPDATE_TYPE				= 8,
	CLEAR_SHOWN_CONSTRS		= 9,
	ADD_SHOWN_CONSTRS		= 10,
	GET_DATA_FOR_EDITOR		= 11,
	GET_DEF_DATA_FOR_EDITOR	= 12,
	CLEAR_EDITOR_DATA		= 13,
	FILL_EDITOR			= 14,
	FORGET_CONSTR			= 15,
	TRANSFER_CONSTR_ENTS	= 16,
	TRANSFER_CONSTRS_ENTS	= 17,
}

ConstraintEditor.NetBitCounts = {
	TAG			= 5,
	ENT_COUNT	= 13, -- up to 8192 entities can exist
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
