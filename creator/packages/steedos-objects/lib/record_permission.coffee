Clone = require('clone')

### owner 权限使用规则(对象配置了owner权限)###
# 1 当record 为空或record._id不存在时，则认为是新建，使用owner权限
# 2 当record.owner 等于当前用户时， 使用owner权限

Creator._recordSafeObjectCache = []

setCache = (record, object_name, data)->
	cacheKey = 'other'
	if isMyRecord(record)
		cacheKey = 'my'
	if Creator._recordSafeObjectCache[object_name]
		Creator._recordSafeObjectCache[object_name][cacheKey] = data
	else
		Creator._recordSafeObjectCache[object_name] = {"#{cacheKey}": data}

getCache = (record, object_name)->
	cacheKey = 'other'
	if isMyRecord(record)
		cacheKey = 'my'
	return Creator._recordSafeObjectCache[object_name]?[cacheKey]

isMyRecord = (record)->
	if _.isEmpty(record) || !_.has(record, '_id')
		return true
	if _.isString(record.owner) && record.owner == Meteor.userId()
		return true
	if record.owner && _.has(record.owner, '_id') && record.owner._id == Meteor.userId()
		return true
	return false


getUnReadableFields = (record, permissions)->
	if !permissions
		return
	unreadable_fields = permissions?.unreadable_fields

	if !_.has(permissions, 'owner')
		return unreadable_fields

	owner_permissions = permissions.owner
	if isMyRecord(record)
		if _.has(owner_permissions, 'unreadable_fields')
			return _.intersection(unreadable_fields, owner_permissions.unreadable_fields)
	return unreadable_fields

getUnEditableFields = (record, permissions)->
	if !permissions
		return
	uneditable_fields = permissions?.uneditable_fields

	if !_.has(permissions, 'owner')
		return uneditable_fields

	owner_permissions = permissions.owner
	if isMyRecord(record)
		if _.has(owner_permissions, 'uneditable_fields')
			return _.intersection(uneditable_fields, owner_permissions.uneditable_fields)
	return uneditable_fields

getUnEditableRelatedList = (record, permissions)->
	if !permissions
		return
	uneditable_related_list = permissions?.uneditable_related_list

	if !_.has(permissions, 'owner')
		return uneditable_related_list

	owner_permissions = permissions.owner
	if isMyRecord(record)
		if _.has(owner_permissions, 'uneditable_related_list')
			return _.intersection(uneditable_related_list, owner_permissions.uneditable_related_list)
	return uneditable_related_list

Creator.getRecordSafeObject = (record, object_name)->

	dataCache = getCache(record, object_name);

	if dataCache
		return dataCache;

	object = Clone(Creator.getObject(object_name, Session.get("spaceId")))
	permissions = object.permissions.get()
	unreadable_fields = getUnReadableFields(record, permissions)
	uneditable_fields = getUnEditableFields(record, permissions)
	uneditable_related_list = getUnEditableRelatedList(record, permissions);
	_.each object.fields, (field, field_name)->
		if field
			if _.indexOf(unreadable_fields, field_name) < 0
				if field.hidden
					return
				if _.indexOf(uneditable_fields, field_name) > -1
					field.readonly = true
					field.disabled = true
					# 当只读时，如果不去掉必填字段，autoform是会报错的
					field.required = false
			else
				field.hidden = true
	object.uneditable_related_list = uneditable_related_list
	setCache(record, object_name, object)
	return object


Creator.getRecordSafeFields = (record, object_name)->
	safeObject = Creator.getRecordSafeObject(record, object_name)
	fields = {};
	_.each _.sortBy(safeObject.fields, "sort_no"), (v)->
		fields[v.name] = v
	return fields;

Creator.getRecordSafeField = (field, record, object_name)->
	safeFields = Creator.getRecordSafeFields(record, object_name);
	return safeFields[field?.name]

Creator.getRecordSafeObjectSchema = (record, object_name)->
	safeObject = Creator.getRecordSafeObject(record, object_name)
	return Creator.getObjectSchema(safeObject)

Creator.getRecordSafeRelatedList = (record, object_name)->
	safeObject = Creator.getRecordSafeObject(record, object_name)
	return safeObject.uneditable_related_list || []
