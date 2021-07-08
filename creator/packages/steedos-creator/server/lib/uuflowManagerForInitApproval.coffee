_eval = require('eval')
uuflowManagerForInitApproval = {}

uuflowManagerForInitApproval.check_authorization = (req) ->
	query = req.query
	userId = query["X-User-Id"]
	authToken = query["X-Auth-Token"]

	if not userId or not authToken
		throw new Meteor.Error 401, 'Unauthorized'

	hashedToken = Accounts._hashLoginToken(authToken)
	user = Meteor.users.findOne
		_id: userId,
		"services.resume.loginTokens.hashedToken": hashedToken

	if not user
		throw new Meteor.Error 401, 'Unauthorized'

	return user

uuflowManagerForInitApproval.getSpace = (space_id) ->
	space = Creator.Collections.spaces.findOne(space_id)
	if not space
		throw new Meteor.Error('error!', "space_id有误或此space已经被删除")
	return space

uuflowManagerForInitApproval.getFlow = (flow_id) ->
	flow = Creator.Collections.flows.findOne(flow_id)
	if not flow
		throw new Meteor.Error('error!', "id有误或此流程已经被删除")
	return flow

uuflowManagerForInitApproval.getSpaceUser = (space_id, user_id) ->
	space_user = Creator.Collections.space_users.findOne({ space: space_id, user: user_id })
	if not space_user
		throw new Meteor.Error('error!', "user_id对应的用户不属于当前space")
	return space_user

uuflowManagerForInitApproval.getSpaceUserOrgInfo = (space_user) ->
	info = new Object
	info.organization = space_user.organization
	org = Creator.Collections.organizations.findOne(space_user.organization, { fields: { name: 1 , fullname: 1 } })
	info.organization_name = org.name
	info.organization_fullname = org.fullname
	return info

uuflowManagerForInitApproval.isFlowEnabled = (flow) ->
	if flow.state isnt "enabled"
		throw new Meteor.Error('error!', "流程未启用,操作失败")

uuflowManagerForInitApproval.isFlowSpaceMatched = (flow, space_id) ->
	if flow.space isnt space_id
		throw new Meteor.Error('error!', "流程和工作区ID不匹配")

uuflowManagerForInitApproval.getForm = (form_id) ->
	form = Creator.Collections.forms.findOne(form_id)
	if not form
		throw new Meteor.Error('error!', '表单ID有误或此表单已经被删除')

	return form

uuflowManagerForInitApproval.getCategory = (category_id) ->
	return Creator.Collections.categories.findOne(category_id)

uuflowManagerForInitApproval.create_instance = (instance_from_client, user_info) ->
	check instance_from_client["applicant"], String
	check instance_from_client["space"], String
	check instance_from_client["flow"], String
	check instance_from_client["record_ids"], [{o: String, ids: [String]}]

	# 校验是否record已经发起的申请还在审批中
	uuflowManagerForInitApproval.checkIsInApproval(instance_from_client["record_ids"][0], instance_from_client["space"])

	space_id = instance_from_client["space"]
	flow_id = instance_from_client["flow"]
	user_id = user_info._id
	# 获取前台所传的trace
	trace_from_client = null
	# 获取前台所传的approve
	approve_from_client = null
	if instance_from_client["traces"] and instance_from_client["traces"][0]
		trace_from_client = instance_from_client["traces"][0]
		if trace_from_client["approves"] and trace_from_client["approves"][0]
			approve_from_client = instance_from_client["traces"][0]["approves"][0]

	# 获取一个space
	space = uuflowManagerForInitApproval.getSpace(space_id)
	# 获取一个flow
	flow = uuflowManagerForInitApproval.getFlow(flow_id)
	# 获取一个space下的一个user
	space_user = uuflowManagerForInitApproval.getSpaceUser(space_id, user_id)
	# 获取space_user所在的部门信息
	space_user_org_info = uuflowManagerForInitApproval.getSpaceUserOrgInfo(space_user)
	# 判断一个flow是否为启用状态
	uuflowManagerForInitApproval.isFlowEnabled(flow)
	# 判断一个flow和space_id是否匹配
	uuflowManagerForInitApproval.isFlowSpaceMatched(flow, space_id)

	form = uuflowManagerForInitApproval.getForm(flow.form)

	permissions = permissionManager.getFlowPermissions(flow_id, user_id)

	if not permissions.includes("add")
		throw new Meteor.Error('error!', "当前用户没有此流程的新建权限")

	now = new Date
	ins_obj = {}
	ins_obj._id = Creator.Collections.instances._makeNewID()
	ins_obj.space = space_id
	ins_obj.flow = flow_id
	ins_obj.flow_version = flow.current._id
	ins_obj.form = flow.form
	ins_obj.form_version = flow.current.form_version
	ins_obj.name = flow.name
	ins_obj.submitter = user_id
	ins_obj.submitter_name = user_info.name
	ins_obj.applicant = if instance_from_client["applicant"] then instance_from_client["applicant"] else user_id
	ins_obj.applicant_name = if instance_from_client["applicant_name"] then instance_from_client["applicant_name"] else user_info.name
	ins_obj.applicant_organization = if instance_from_client["applicant_organization"] then instance_from_client["applicant_organization"] else space_user.organization
	ins_obj.applicant_organization_name = if instance_from_client["applicant_organization_name"] then instance_from_client["applicant_organization_name"] else space_user_org_info.organization_name
	ins_obj.applicant_organization_fullname = if instance_from_client["applicant_organization_fullname"] then instance_from_client["applicant_organization_fullname"] else  space_user_org_info.organization_fullname
	ins_obj.applicant_company = if instance_from_client["applicant_company"] then instance_from_client["applicant_company"] else space_user.company_id
	ins_obj.state = 'draft'
	ins_obj.code = ''
	ins_obj.is_archived = false
	ins_obj.is_deleted = false
	ins_obj.created = now
	ins_obj.created_by = user_id
	ins_obj.modified = now
	ins_obj.modified_by = user_id
	ins_obj.values = new Object

	ins_obj.record_ids = instance_from_client["record_ids"]

	if space_user.company_id
		ins_obj.company_id = space_user.company_id

	# 新建Trace
	trace_obj = {}
	trace_obj._id = new Mongo.ObjectID()._str
	trace_obj.instance = ins_obj._id
	trace_obj.is_finished = false
	# 当前最新版flow中开始节点
	start_step = _.find(flow.current.steps, (step) ->
		return step.step_type is 'start'
	)
	trace_obj.step = start_step._id
	trace_obj.name = start_step.name

	trace_obj.start_date = now
	# 新建Approve
	appr_obj = {}
	appr_obj._id = new Mongo.ObjectID()._str
	appr_obj.instance = ins_obj._id
	appr_obj.trace = trace_obj._id
	appr_obj.is_finished = false
	appr_obj.user = if instance_from_client["applicant"] then instance_from_client["applicant"] else user_id
	appr_obj.user_name = if instance_from_client["applicant_name"] then instance_from_client["applicant_name"] else user_info.name
	appr_obj.handler = user_id
	appr_obj.handler_name = user_info.name
	appr_obj.handler_organization = space_user.organization
	appr_obj.handler_organization_name = space_user_org_info.name
	appr_obj.handler_organization_fullname = space_user_org_info.fullname
	appr_obj.type = 'draft'
	appr_obj.start_date = now
	appr_obj.read_date = now
	appr_obj.is_read = true
	appr_obj.is_error = false
	appr_obj.description = ''
	relatedTablesInfo = {}
	appr_obj.values = uuflowManagerForInitApproval.initiateValues(ins_obj.record_ids[0], flow_id, space_id, form.current.fields, relatedTablesInfo)

	trace_obj.approves = [appr_obj]
	ins_obj.traces = [trace_obj]

	ins_obj.inbox_users = instance_from_client.inbox_users || []

	ins_obj.current_step_name = start_step.name

	if flow.auto_remind is true
		ins_obj.auto_remind = true

	# 新建申请单时，instances记录流程名称、流程分类名称 #1313
	ins_obj.flow_name = flow.name
	if form.category
		category = uuflowManagerForInitApproval.getCategory(form.category)
		if category
			ins_obj.category_name = category.name
			ins_obj.category = category._id

	new_ins_id = Creator.Collections.instances.insert(ins_obj)

	uuflowManagerForInitApproval.initiateRecordInstanceInfo(ins_obj.record_ids[0], new_ins_id, space_id)

	uuflowManagerForInitApproval.initiateRelatedRecordInstanceInfo(relatedTablesInfo, new_ins_id, space_id)

	uuflowManagerForInitApproval.initiateAttach(ins_obj.record_ids[0], space_id, ins_obj._id, appr_obj._id)

	return new_ins_id

uuflowManagerForInitApproval.initiateValues = (recordIds, flowId, spaceId, fields, relatedTablesInfo) ->
	fieldCodes = []
	_.each fields, (f) ->
		if f.type == 'section'
			_.each f.fields, (ff) ->
				fieldCodes.push ff.code
		else
			fieldCodes.push f.code

	values = {}
	objectName = recordIds.o
	object = Creator.getObject(objectName, spaceId)
	recordId = recordIds.ids[0]
	ow = Creator.Collections.object_workflows.findOne({
		object_name: objectName,
		flow_id: flowId
	})
	record = Creator.getCollection(objectName, spaceId).findOne(recordId)
	flow = Creator.getCollection('flows').findOne(flowId, { fields: { form: 1 } })
	if ow and record
		form = Creator.getCollection("forms").findOne(flow.form)
		formFields = form.current.fields || []
		relatedObjects = Creator.getRelatedObjects(objectName, spaceId)
		relatedObjectsKeys = _.pluck(relatedObjects, 'object_name')
		formTableFields = _.filter formFields, (formField) ->
			return formField.type == 'table'
		formTableFieldsCode = _.pluck(formTableFields, 'code')

		getRelatedObjectFieldCode =  (key) ->
			return _.find relatedObjectsKeys,  (relatedObjectsKey) ->
				return key.startsWith(relatedObjectsKey + '.')

		getFormTableFieldCode = (key) ->
			return _.find formTableFieldsCode,  (formTableFieldCode) ->
				return key.startsWith(formTableFieldCode + '.')

		getFormTableField = (key) ->
			return _.find formTableFields,  (f) ->
				return f.code == key

		getFormField = (key) ->
			return _.find formFields,  (f) ->
				return f.code == key

		getFormTableSubField = (tableField, subFieldCode) ->
			return _.find tableField.fields,  (f) ->
				return f.code == subFieldCode

		getFieldOdataValue = (objName, id) ->
			obj = Creator.getCollection(objName)
			if !obj
				return
			if _.isString id
				_record = obj.findOne(id)
				if _record
					_record['@label'] = _record.name
					return _record
			else if _.isArray id
				_records = []
				obj.find({ _id: { $in: id } }).forEach (_record) ->
					_record['@label'] = _record.name
					_records.push _record

				if !_.isEmpty _records
					return _records
			return

		getSelectUserValue = (userId, spaceId) ->
			su = Creator.getCollection('space_users').findOne({ space: spaceId, user: userId })
			su.id = userId
			return su

		getSelectUserValues = (userIds, spaceId) ->
			sus = []
			if _.isArray userIds
				_.each userIds, (userId) ->
					su = getSelectUserValue(userId, spaceId)
					if su
						sus.push(su)
			return sus

		getSelectOrgValue = (orgId, spaceId) ->
			org = Creator.getCollection('organizations').findOne(orgId, { fields: { _id: 1, name: 1, fullname: 1 } })
			org.id = orgId
			return org

		getSelectOrgValues = (orgIds, spaceId) ->
			orgs = []
			if _.isArray orgIds
				_.each orgIds, (orgId) ->
					org = getSelectOrgValue(orgId, spaceId)
					if org
						orgs.push(org)
			return orgs

		tableFieldCodes = []
		tableFieldMap = []
		tableToRelatedMap = {}

		ow.field_map?.forEach (fm) ->
			object_field = fm.object_field
			workflow_field = fm.workflow_field
			relatedObjectFieldCode = getRelatedObjectFieldCode(object_field)
			formTableFieldCode = getFormTableFieldCode(workflow_field)
			objField = object.fields[object_field]
			formField = getFormField(workflow_field)
			# 处理子表字段
			if relatedObjectFieldCode
				
				oTableCode = object_field.split('.')[0]
				oTableFieldCode = object_field.split('.')[1]
				tableToRelatedMapKey = oTableCode
				if !tableToRelatedMap[tableToRelatedMapKey]
					tableToRelatedMap[tableToRelatedMapKey] = {}

				if formTableFieldCode
					wTableCode = workflow_field.split('.')[0]
					tableToRelatedMap[tableToRelatedMapKey]['_FROM_TABLE_CODE'] = wTableCode

				tableToRelatedMap[tableToRelatedMapKey][oTableFieldCode] = workflow_field
			# 判断是否是表格字段
			else if workflow_field.indexOf('.$.') > 0 and object_field.indexOf('.$.') > 0
				wTableCode = workflow_field.split('.$.')[0]
				oTableCode = object_field.split('.$.')[0]
				if record.hasOwnProperty(oTableCode) and _.isArray(record[oTableCode])
					tableFieldCodes.push(JSON.stringify({
						workflow_table_field_code: wTableCode,
						object_table_field_code: oTableCode
					}))
					tableFieldMap.push(fm)

			# 处理lookup、master_detail类型字段
			else if object_field.indexOf('.') > 0 and object_field.indexOf('.$.') == -1
				objectFieldName = object_field.split('.')[0]
				lookupFieldName = object_field.split('.')[1]
				if object
					objectField = object.fields[objectFieldName]
					if objectField && formField && ['lookup', 'master_detail'].includes(objectField.type) && _.isString(objectField.reference_to)
						fieldsObj = {}
						fieldsObj[lookupFieldName] = 1
						lookupObjectRecord = Creator.getCollection(objectField.reference_to, spaceId).findOne(record[objectFieldName], { fields: fieldsObj })
						objectFieldObjectName = objectField.reference_to
						lookupFieldObj = Creator.getObject(objectFieldObjectName, spaceId)
						objectLookupField = lookupFieldObj.fields[lookupFieldName]
						referenceToFieldValue = lookupObjectRecord[lookupFieldName]
						if objectLookupField && formField && formField.type == 'odata' && ['lookup', 'master_detail'].includes(objectLookupField.type) && _.isString(objectLookupField.reference_to)
							referenceToObjectName = objectLookupField.reference_to
							odataFieldValue
							if objectField.multiple && formField.is_multiselect
								odataFieldValue = getFieldOdataValue(referenceToObjectName, referenceToFieldValue)
							else if !objectField.multiple && !formField.is_multiselect
								odataFieldValue = getFieldOdataValue(referenceToObjectName, referenceToFieldValue)
							values[workflow_field] = odataFieldValue
						else
							values[workflow_field] = lookupObjectRecord[lookupFieldName]

			# lookup、master_detail字段同步到odata字段
			else if formField && objField && formField.type == 'odata' && ['lookup', 'master_detail'].includes(objField.type) && _.isString(objField.reference_to)
				referenceToObjectName = objField.reference_to
				referenceToFieldValue = record[objField.name]
				odataFieldValue
				if objField.multiple && formField.is_multiselect
					odataFieldValue = getFieldOdataValue(referenceToObjectName, referenceToFieldValue)
				else if !objField.multiple && !formField.is_multiselect
					odataFieldValue = getFieldOdataValue(referenceToObjectName, referenceToFieldValue)
				values[workflow_field] = odataFieldValue
			else if formField && objField && ['user', 'group'].includes(formField.type) && ['lookup', 'master_detail'].includes(objField.type) && ['users', 'organizations'].includes(objField.reference_to)
				referenceToFieldValue = record[objField.name]
				if !_.isEmpty(referenceToFieldValue)
					selectFieldValue
					if formField.type == 'user'
						if objField.multiple && formField.is_multiselect
							selectFieldValue = getSelectUserValues(referenceToFieldValue, spaceId)
						else if !objField.multiple && !formField.is_multiselect
							selectFieldValue = getSelectUserValue(referenceToFieldValue, spaceId)
					else if formField.type == 'group'
						if objField.multiple && formField.is_multiselect
							selectFieldValue = getSelectOrgValues(referenceToFieldValue, spaceId)
						else if !objField.multiple && !formField.is_multiselect
							selectFieldValue = getSelectOrgValue(referenceToFieldValue, spaceId)
					if selectFieldValue
						values[workflow_field] = selectFieldValue
			else if record.hasOwnProperty(object_field)
				values[workflow_field] = record[object_field]

		# 表格字段
		_.uniq(tableFieldCodes).forEach (tfc) ->
			c = JSON.parse(tfc)
			values[c.workflow_table_field_code] = []
			record[c.object_table_field_code].forEach (tr) ->
				newTr = {}
				_.each tr, (v, k) ->
					tableFieldMap.forEach (tfm) ->
						if tfm.object_field is (c.object_table_field_code + '.$.' + k)
							wTdCode = tfm.workflow_field.split('.$.')[1]
							newTr[wTdCode] = v
				if not _.isEmpty(newTr)
					values[c.workflow_table_field_code].push(newTr)

		# 同步子表数据至表单表格
		_.each tableToRelatedMap,  (map, key) ->
			tableCode = map._FROM_TABLE_CODE
			formTableField = getFormTableField(tableCode)
			if !tableCode
				console.warn('tableToRelated: [' + key + '] missing corresponding table.')
			else
				relatedObjectName = key
				tableValues = []
				relatedTableItems = []
				relatedObject = Creator.getObject(relatedObjectName, spaceId)
				relatedField = _.find relatedObject.fields, (f) ->
					return ['lookup', 'master_detail'].includes(f.type) && f.reference_to == objectName

				relatedFieldName = relatedField.name

				selector = {}
				selector[relatedFieldName] = recordId
				relatedCollection = Creator.getCollection(relatedObjectName, spaceId)
				relatedRecords = relatedCollection.find(selector)

				relatedRecords.forEach (rr) ->
					tableValueItem = {}
					_.each map, (valueKey, fieldKey) ->
						if fieldKey != '_FROM_TABLE_CODE'
							tableFieldValue
							formFieldKey
							if valueKey.startsWith(tableCode + '.')
								formFieldKey = (valueKey.split(".")[1])
							else
								formFieldKey = valueKey
							
							formField = getFormTableSubField(formTableField, formFieldKey)
							relatedObjectField = relatedObject.fields[fieldKey]
							if !formField || !relatedObjectField
								return
							if formField.type == 'odata' && ['lookup', 'master_detail'].includes(relatedObjectField.type) && _.isString(relatedObjectField.reference_to)
								referenceToObjectName = relatedObjectField.reference_to
								referenceToFieldValue = rr[fieldKey]
								if relatedObjectField.multiple && formField.is_multiselect
									tableFieldValue = getFieldOdataValue(referenceToObjectName, referenceToFieldValue)
								else if !relatedObjectField.multiple && !formField.is_multiselect
									tableFieldValue = getFieldOdataValue(referenceToObjectName, referenceToFieldValue)
							else if ['user', 'group'].includes(formField.type) && ['lookup', 'master_detail'].includes(relatedObjectField.type) && ['users', 'organizations'].includes(relatedObjectField.reference_to)
								referenceToFieldValue = rr[fieldKey]
								if !_.isEmpty(referenceToFieldValue)
									if formField.type == 'user'
										if relatedObjectField.multiple && formField.is_multiselect
											tableFieldValue = getSelectUserValues(referenceToFieldValue, spaceId)
										else if !relatedObjectField.multiple && !formField.is_multiselect
											tableFieldValue = getSelectUserValue(referenceToFieldValue, spaceId)
									else if formField.type == 'group'
										if relatedObjectField.multiple && formField.is_multiselect
											tableFieldValue = getSelectOrgValues(referenceToFieldValue, spaceId)
										else if !relatedObjectField.multiple && !formField.is_multiselect
											tableFieldValue = getSelectOrgValue(referenceToFieldValue, spaceId)
							else
								tableFieldValue = rr[fieldKey]
							tableValueItem[formFieldKey] = tableFieldValue
					if !_.isEmpty(tableValueItem)
						tableValueItem._id = rr._id
						tableValues.push(tableValueItem)
						relatedTableItems.push({ _table: { _id: rr._id, _code: tableCode } } )

				values[tableCode] = tableValues
				relatedTablesInfo[relatedObjectName] = relatedTableItems

		# 如果配置了脚本则执行脚本
		if ow.field_map_script
			_.extend(values, uuflowManagerForInitApproval.evalFieldMapScript(ow.field_map_script, objectName, spaceId, recordId))

	# 过滤掉values中的非法key
	filterValues = {}
	_.each _.keys(values), (k) ->
		if fieldCodes.includes(k)
			filterValues[k] = values[k]

	return filterValues

uuflowManagerForInitApproval.evalFieldMapScript = (field_map_script, objectName, spaceId, objectId) ->
	record = Creator.getCollection(objectName, spaceId).findOne(objectId)
	script = "module.exports = function (record) { " + field_map_script + " }"
	func = _eval(script, "field_map_script")
	values = func(record)
	if _.isObject values
		return values
	else
		console.error "evalFieldMapScript: 脚本返回值类型不是对象"
	return {}



uuflowManagerForInitApproval.initiateAttach = (recordIds, spaceId, insId, approveId) ->

	Creator.Collections['cms_files'].find({
		space: spaceId,
		parent: recordIds
	}).forEach (cf) ->
		_.each cf.versions, (versionId, idx) ->
			f = Creator.Collections['cfs.files.filerecord'].findOne(versionId)
			newFile = new FS.File()

			newFile.attachData f.createReadStream('files'), {
					type: f.original.type
			}, (err) ->
				if (err)
					throw new Meteor.Error(err.error, err.reason)

				newFile.name(f.name())
				newFile.size(f.size())
				metadata = {
					owner: f.metadata.owner,
					owner_name: f.metadata.owner_name,
					space: spaceId,
					instance: insId,
					approve: approveId
					parent: cf._id
				}

				if idx is 0
					metadata.current = true

				newFile.metadata = metadata
				cfs.instances.insert(newFile)

	return

uuflowManagerForInitApproval.initiateRecordInstanceInfo = (recordIds, insId, spaceId) ->
	Creator.getCollection(recordIds.o, spaceId).update(recordIds.ids[0], {
		$push: {
			instances: {
				$each: [{
					_id: insId,
					state: 'draft'
				}],
				$position: 0
			}
		},
		$set: {
			locked: true
			instance_state: 'draft'
		}
	})

	return


uuflowManagerForInitApproval.initiateRelatedRecordInstanceInfo = (relatedTablesInfo, insId, spaceId) ->
	_.each relatedTablesInfo, (tableItems, relatedObjectName) ->
		relatedCollection = Creator.getCollection(relatedObjectName, spaceId)
		_.each tableItems, (item) ->
			relatedCollection.update(item._table._id, {
				$set: {
					instances: [{
						_id: insId,
						state: 'draft'
					}],
					_table: item._table
				}
			})

	return

uuflowManagerForInitApproval.checkIsInApproval = (recordIds, spaceId) ->
	record = Creator.getCollection(recordIds.o, spaceId).findOne({
		_id: recordIds.ids[0], instances: { $exists: true }
	}, { fields: { instances: 1 } })

	if record and record.instances[0].state isnt 'completed' and Creator.Collections.instances.find(record.instances[0]._id).count() > 0
		throw new Meteor.Error('error!', "此记录已发起流程正在审批中，待审批结束方可发起下一次审批！")

	return

