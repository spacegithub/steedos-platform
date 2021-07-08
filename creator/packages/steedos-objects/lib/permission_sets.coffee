clone = require('clone')

Creator.getPermissions = (object_name, spaceId, userId)->
	if Meteor.isClient
		if !object_name
			object_name = Session.get("object_name")
		obj = Creator.getObject(object_name)
		if !obj
			return
		return obj.permissions.get()
	else if Meteor.isServer
		Creator.getObjectPermissions(spaceId, userId, object_name)

Creator.getRecordPermissions = (object_name, record, userId, spaceId)->
	if !object_name and Meteor.isClient
		object_name = Session.get("object_name")

	if !spaceId and Meteor.isClient
		spaceId = Session.get("spaceId")
	
	if record and object_name == "cms_files" and Meteor.isClient
		# 如果是cms_files附件，则权限取其父记录权限
		if object_name == Session.get('object_name')
			# 当前处于cms_files附件详细界面
			object_name = record.parent['reference_to._o'];
			record_id = record.parent._id;
		else 
			# 当前处于cms_files附件的父记录界面
			object_name = Session.get('object_name');
			record_id = Session.get("record_id");
		object_fields_keys = _.keys(Creator.getObject(object_name, spaceId)?.fields or {}) || [];
		select = _.intersection(object_fields_keys, ['owner', 'company_id', 'company_ids', 'locked']) || [];
		if select.length > 0
			record = Creator.getObjectRecord(object_name, record_id, select.join(','));
		else
			record = null;

	permissions = _.clone(Creator.getPermissions(object_name, spaceId, userId))

	if record
		if record.record_permissions
			return record.record_permissions

		isOwner = record.owner == userId || record.owner?._id == userId
		if Meteor.isClient
			user_company_ids = Steedos.getUserCompanyIds()
		else
			user_company_ids = Creator.getUserCompanyIds(userId, spaceId)
		record_company_id = record?.company_id
		if record_company_id and _.isObject(record_company_id) and record_company_id._id
			# 因record_company_id是lookup类型，有可能dx控件会把它映射转为对应的object，所以这里取出其_id值
			record_company_id = record_company_id._id
		record_company_ids = record?.company_ids
		if record_company_ids and record_company_ids.length and _.isObject(record_company_ids[0])
			# 因record_company_ids是lookup类型，有可能dx控件会把它映射转为对应的[object]，所以这里取出其_id值
			record_company_ids = record_company_ids.map((n)-> n._id)
		record_company_ids = _.union(record_company_ids, [record_company_id])
		if !permissions.modifyAllRecords and !isOwner and !permissions.modifyCompanyRecords
			permissions.allowEdit = false
			permissions.allowDelete = false
		else if !permissions.modifyAllRecords and permissions.modifyCompanyRecords
			if record_company_ids and record_company_ids.length
				if user_company_ids and user_company_ids.length
					if !_.intersection(user_company_ids, record_company_ids).length
						# 记录的company_id/company_ids属性不在当前用户user_company_ids范围内时，认为无权修改
						permissions.allowEdit = false
						permissions.allowDelete = false
				else
					# 记录有company_id/company_ids属性，但是当前用户user_company_ids为空时，认为无权修改
					permissions.allowEdit = false
					permissions.allowDelete = false
		
		if record.locked and !permissions.modifyAllRecords
			permissions.allowEdit = false
			permissions.allowDelete = false

		if !permissions.viewAllRecords and !isOwner and !permissions.viewCompanyRecords
			permissions.allowRead = false
		else if !permissions.viewAllRecords and permissions.viewCompanyRecords
			if record_company_ids and record_company_ids.length
				if user_company_ids and user_company_ids.length
					if !_.intersection(user_company_ids, record_company_ids).length
						# 记录的company_id/company_ids属性不在当前用户user_company_ids范围内时，认为无权查看
						permissions.allowRead = false
				else
					# 记录有company_id属性，但是当前用户user_company_ids为空时，认为无权查看
					permissions.allowRead = false

	return permissions


# currentObjectName：当前主对象
# relatedListItem：Creator.getRelatedList(Session.get("object_name"), Session.get("record_id"))中取related_object_name对应的值
# currentRecord当前主对象的详细记录
if Meteor.isClient
	Creator.getRecordRelatedListPermissions = (currentObjectName, relatedListItem, currentRecord, userId, spaceId)->
		if !currentObjectName and Meteor.isClient
			currentObjectName = Session.get("object_name")

		if !relatedListItem
			console.error("relatedListItem must not be empty for the function Creator.getRecordRelatedListPermissions");
			return {}

		if !currentRecord and Meteor.isClient
			currentRecord = Creator.getObjectRecord()

		if !userId and Meteor.isClient
			userId = Meteor.userId()

		if !spaceId and Meteor.isClient
			spaceId = Session.get("spaceId")

		sharing = relatedListItem.sharing || 'masterWrite'
		masterAllow = false
		masterRecordPerm = Creator.getRecordPermissions(currentObjectName, currentRecord, userId, spaceId)
		if sharing == 'masterRead'
			masterAllow = masterRecordPerm.allowRead
		else if sharing == 'masterWrite'
			masterAllow = masterRecordPerm.allowEdit

		uneditable_related_list = Creator.getRecordSafeRelatedList(currentRecord, currentObjectName)
		relatedObjectPermissions = Creator.getPermissions(relatedListItem.object_name)
		isRelateObjectUneditable = uneditable_related_list.indexOf(relatedListItem.object_name) > -1

		result = _.clone relatedObjectPermissions
		result.allowCreate = masterAllow && relatedObjectPermissions.allowCreate && !isRelateObjectUneditable
		result.allowEdit = masterAllow && relatedObjectPermissions.allowEdit && !isRelateObjectUneditable
		return result

if Meteor.isServer

	Creator.getAllPermissions = (spaceId, userId) ->
		permissions =
			objects: {}
			assigned_apps: []
		###
		权限集说明:
		内置权限集-admin,user,member,guest,workflow_admin,organization_admin
		自定义权限集-数据库中新建的除内置权限集以外的其他权限集
		特定用户集合权限集（即users属性不可配置）-admin,user,member,guest
		可配置用户集合权限集（即users属性可配置）-workflow_admin,organization_admin以及自定义权限集
		###

		isSpaceAdmin = false
		spaceUser = null
		if userId
			isSpaceAdmin = Creator.isSpaceAdmin(spaceId, userId)
			spaceUser = Creator.getCollection("space_users").findOne({ space: spaceId, user: userId }, { fields: { profile: 1 } })

		psetsAdmin = Creator.getCollection("permission_set").findOne({space: spaceId, name: 'admin'}, {fields:{_id:1, assigned_apps:1}}) || null
		psetsUser = Creator.getCollection("permission_set").findOne({space: spaceId, name: 'user'}, {fields:{_id:1, assigned_apps:1}}) || null
		psetsMember = Creator.getCollection("permission_set").findOne({space: spaceId, name: 'member'}, {fields:{_id:1, assigned_apps:1}}) || null
		psetsGuest = Creator.getCollection("permission_set").findOne({space: spaceId, name: 'guest'}, {fields:{_id:1, assigned_apps:1}}) || null

		psetsSupplier = Creator.getCollection("permission_set").findOne({space: spaceId, name: 'supplier'}, {fields:{_id:1, assigned_apps:1}}) || null
		psetsCustomer = Creator.getCollection("permission_set").findOne({space: spaceId, name: 'customer'}, {fields:{_id:1, assigned_apps:1}}) || null
		if spaceUser && spaceUser.profile
			psetsCurrent = Creator.getCollection("permission_set").find({space: spaceId, $or: [{users: userId}, {name: spaceUser.profile}]}, {fields:{_id:1, assigned_apps:1, name:1}}).fetch()
		else
			psetsCurrent = Creator.getCollection("permission_set").find({users: userId, space: spaceId}, {fields:{_id:1, assigned_apps:1, name:1}}).fetch()

		psetsAdmin_pos = null
		psetsUser_pos = null
		psetsMember_pos = null
		psetsGuest_pos = null
		psetsCurrent_pos = null
		psetsSupplier_pos = null
		psetsCustomer_pos = null

		if psetsAdmin?._id
			psetsAdmin_pos = Creator.getCollection("permission_objects").find({permission_set_id: psetsAdmin._id}, {fields: {created: 0, modified: 0, created_by: 0, modified_by: 0}}).fetch()
		if psetsUser?._id
			psetsUser_pos = Creator.getCollection("permission_objects").find({permission_set_id: psetsUser._id}, {fields: {created: 0, modified: 0, created_by: 0, modified_by: 0}}).fetch()
		if psetsMember?._id
			psetsMember_pos = Creator.getCollection("permission_objects").find({permission_set_id: psetsMember._id}, {fields: {created: 0, modified: 0, created_by: 0, modified_by: 0}}).fetch()
		if psetsGuest?._id
			psetsGuest_pos = Creator.getCollection("permission_objects").find({permission_set_id: psetsGuest._id}, {fields: {created: 0, modified: 0, created_by: 0, modified_by: 0}}).fetch()
		if psetsSupplier?._id
			psetsSupplier_pos = Creator.getCollection("permission_objects").find({permission_set_id: psetsSupplier._id}, {fields: {created: 0, modified: 0, created_by: 0, modified_by: 0}}).fetch()
		if psetsCustomer?._id
			psetsCustomer_pos = Creator.getCollection("permission_objects").find({permission_set_id: psetsCustomer._id}, {fields: {created: 0, modified: 0, created_by: 0, modified_by: 0}}).fetch()

		if psetsCurrent.length > 0
			set_ids = _.pluck psetsCurrent, "_id"
			psetsCurrent_pos = Creator.getCollection("permission_objects").find({permission_set_id: {$in: set_ids}}).fetch()
			psetsCurrentNames = _.pluck psetsCurrent, "name"

		psets = {
			psetsAdmin, 
			psetsUser, 
			psetsCurrent, 
			psetsMember, 
			psetsGuest,
			psetsSupplier,
			psetsCustomer,
			isSpaceAdmin,
			spaceUser, 
			psetsAdmin_pos, 
			psetsUser_pos, 
			psetsMember_pos, 
			psetsGuest_pos,
			psetsSupplier_pos,
			psetsCustomer_pos,
			psetsCurrent_pos
		}
		permissions.assigned_apps = Creator.getAssignedApps.bind(psets)(spaceId, userId)
		permissions.assigned_menus = Creator.getAssignedMenus.bind(psets)(spaceId, userId)
		permissions.user_permission_sets = psetsCurrentNames
		_i = 0
		_.each Creator.objectsByName, (object, object_name)->
			_i++
			if !_.has(object, 'space') || !object.space || object.space == spaceId
				if !_.has(object, 'in_development') || object.in_development == '0' || (object.in_development != '0' && isSpaceAdmin)
					permissions.objects[object_name] = Creator.convertObject(clone(Creator.Objects[object_name]), spaceId)
					permissions.objects[object_name]["permissions"] = Creator.getObjectPermissions.bind(psets)(spaceId, userId, object_name)
		return permissions

	unionPlus = (array, other) ->
		if !array and !other
			return undefined
		if !array
			array = []
		if !other
			other = []
		return _.union(array, other)

	intersectionPlus = (array, other) ->
		if !array and !other
			return undefined
		if !array
			array = []
		if !other
			other = []
		return _.intersection(array, other)

	Creator.getAssignedApps = (spaceId, userId)->
		psetsAdmin = this.psetsAdmin || Creator.getCollection("permission_set").findOne({space: spaceId, name: 'admin'}, {fields:{_id:1, assigned_apps:1}})
		psetsUser = this.psetsUser || Creator.getCollection("permission_set").findOne({space: spaceId, name: 'user'}, {fields:{_id:1, assigned_apps:1}})
		psetsSupplier = this.psetsMember || Creator.getCollection("permission_set").findOne({space: spaceId, name: 'supplier'}, {fields:{_id:1, assigned_apps:1}})
		psetsCustomer = this.psetsGuest || Creator.getCollection("permission_set").findOne({space: spaceId, name: 'customer'}, {fields:{_id:1, assigned_apps:1}})
		# psetsMember = this.psetsMember || Creator.getCollection("permission_set").findOne({space: spaceId, name: 'member'}, {fields:{_id:1, assigned_apps:1}})
		# psetsGuest = this.psetsGuest || Creator.getCollection("permission_set").findOne({space: spaceId, name: 'guest'}, {fields:{_id:1, assigned_apps:1}})
		psets =  this.psetsCurrent || Creator.getCollection("permission_set").find({users: userId, space: spaceId}, {fields:{_id:1, assigned_apps:1, name:1}}).fetch()
		isSpaceAdmin = if _.isBoolean(this.isSpaceAdmin) then this.isSpaceAdmin else Creator.isSpaceAdmin(spaceId, userId)
		apps = []
		if isSpaceAdmin
			return []
		else
			userProfile = Creator.getCollection("space_users").findOne({space: spaceId, user: userId}, {fields: {profile: 1}})?.profile
			psetBase = psetsUser
			if userProfile
				if userProfile == 'supplier'
					psetBase = psetsSupplier
				else if userProfile == 'customer'
					psetBase = psetsCustomer
			if psetBase?.assigned_apps?.length
				apps = _.union apps, psetBase.assigned_apps
			else
				# user权限集中的assigned_apps表示所有用户具有的apps权限，为空则表示有所有apps权限，不需要作权限判断了
				return []
			_.each psets, (pset)->
				if !pset.assigned_apps
					return
				if pset.name == "admin" ||  pset.name == "user" || pset.name == 'supplier' || pset.name == 'customer'
					# 这里之所以要排除admin/user，是因为这两个权限集是所有权限集中users属性无效的权限集，特指工作区管理员和所有用户
					return
				apps = _.union apps, pset.assigned_apps
			return _.without(_.uniq(apps),undefined,null)

	Creator.getAssignedMenus = (spaceId, userId)->
		psets =  this.psetsCurrent || Creator.getCollection("permission_set").find({users: userId, space: spaceId}, {fields:{_id:1, assigned_apps:1, name:1}}).fetch()
		isSpaceAdmin = if _.isBoolean(this.isSpaceAdmin) then this.isSpaceAdmin else Creator.isSpaceAdmin(spaceId, userId)
		adminMenus = Creator.Apps.admin?.admin_menus
		# 如果没有admin菜单说明不需要相关功能，直接返回空
		unless adminMenus
			return []
		aboutMenu = adminMenus.find (n) ->
			n._id == 'about'
		adminMenus = adminMenus.filter (n) ->
			n._id != 'about'
		otherMenuApps = _.sortBy _.filter(_.values(Creator.Apps), (n) ->
			return n.admin_menus and n._id != 'admin'
		), 'sort'
		otherMenus = _.flatten(_.pluck(otherMenuApps, "admin_menus"))
		# 菜单有三部分组成，设置APP菜单、其他APP菜单以及about菜单
		allMenus = _.union(adminMenus, otherMenus, [aboutMenu])
		if isSpaceAdmin
			# 工作区管理员有全部菜单功能
			result = allMenus
		else
			userProfile = Creator.getCollection("space_users").findOne({space: spaceId, user: userId}, {fields: {profile: 1}})?.profile || 'user'
			currentPsetNames = psets.map (n) ->
				return n.name
			menus = allMenus.filter (menu)->
				psetsMenu = menu.permission_sets
				# 如果普通用户有权限，则直接返回true
				if psetsMenu && psetsMenu.indexOf(userProfile) > -1
					return true
				# 否则取当前用户的权限集与menu菜单要求的权限集对比，如果交集大于1个则返回true
				return _.intersection(currentPsetNames, psetsMenu).length
			result = menus
		
		return _.sortBy(result,"sort")

	findOne_permission_object = (permission_objects, object_name, permission_set_id)->

		if _.isNull(permission_objects)
			return null
		if _.isArray(permission_objects)
			return _.find permission_objects, (po)->
					return po.object_name == object_name
		return Creator.getCollection("permission_objects").findOne({object_name: object_name, permission_set_id: permission_set_id})

	find_permission_object = (permission_objects, object_name, permission_set_ids)->
		if _.isNull(permission_objects)
			return null
		if _.isArray(permission_objects)
			return _.filter permission_objects, (po)->
				return po.object_name == object_name
		Creator.getCollection("permission_objects").find({object_name: object_name, permission_set_id: {$in: permission_set_ids}}).fetch()

	unionPermissionObjects = (pos, object, psets)->
		# 把db及yml中的permission_objects合并，优先取db中的
		result = []
		_.each object.permission_set, (ops, ops_key)->
			# 把yml中除了特定用户集合权限集"admin", "user", "member", "guest"外的其他对象权限先存入result
			# if ["admin", "user", "member", "guest", "workflow_admin", "organization_admin"].indexOf(ops_key) < 0
			if ["admin", "user", "member", "guest"].indexOf(ops_key) < 0
				currentPset = psets.find (pset)-> return pset.name == ops_key
				if currentPset
					tempOps = _.clone(ops) || {}
					tempOps.permission_set_id = currentPset._id
					tempOps.object_name = object.object_name
					result.push tempOps
		if result.length
			pos.forEach (po)->
				repeatIndex = 0
				repeatPo = result.find((item, index)-> repeatIndex = index;return item.permission_set_id == po.permission_set_id)
				# 如果yml中已经存在po，则替换为数据库中的po，反之则把数据库中的po直接累加进去
				if repeatPo
					result[repeatIndex] = po
				else
					result.push po
			return result
		else
			return pos

	Creator.getObjectPermissions = (spaceId, userId, object_name)->
		permissions = {}
		object = Creator.getObject(object_name, spaceId)

		if spaceId is 'guest' || object_name == "users"
			permissions = _.clone(object.permission_set.guest) || {}
			Creator.processPermissions permissions
			return permissions
		psetsAdmin = if _.isNull(this.psetsAdmin) or this.psetsAdmin then this.psetsAdmin else Creator.getCollection("permission_set").findOne({space: spaceId, name: 'admin'}, {fields:{_id:1}})
		psetsUser = if _.isNull(this.psetsUser) or this.psetsUser then this.psetsUser else Creator.getCollection("permission_set").findOne({space: spaceId, name: 'user'}, {fields:{_id:1}})
		psetsMember = if _.isNull(this.psetsMember) or this.psetsMember then this.psetsMember else Creator.getCollection("permission_set").findOne({space: spaceId, name: 'member'}, {fields:{_id:1}})
		psetsGuest = if _.isNull(this.psetsGuest) or this.psetsGuest then this.psetsGuest else Creator.getCollection("permission_set").findOne({space: spaceId, name: 'guest'}, {fields:{_id:1}})

		psetsSupplier = if _.isNull(this.psetsSupplier) or this.psetsSupplier then this.psetsSupplier else Creator.getCollection("permission_set").findOne({space: spaceId, name: 'supplier'}, {fields:{_id:1}})
		psetsCustomer = if _.isNull(this.psetsCustomer) or this.psetsCustomer then this.psetsCustomer else Creator.getCollection("permission_set").findOne({space: spaceId, name: 'customer'}, {fields:{_id:1}})
		psets = this.psetsCurrent || Creator.getCollection("permission_set").find({users: userId, space: spaceId}, {fields:{_id:1, assigned_apps:1, name:1}}).fetch()
		isSpaceAdmin = if _.isBoolean(this.isSpaceAdmin) then this.isSpaceAdmin else Creator.isSpaceAdmin(spaceId, userId)

		psetsAdmin_pos = this.psetsAdmin_pos
		psetsUser_pos = this.psetsUser_pos
		psetsMember_pos = this.psetsMember_pos
		psetsGuest_pos = this.psetsGuest_pos

		psetsSupplier_pos = this.psetsSupplier_pos
		psetsCustomer_pos = this.psetsCustomer_pos

		psetsCurrent_pos = this.psetsCurrent_pos

		opsetAdmin = _.clone(object.permission_set.admin) || {}
		opsetUser = _.clone(object.permission_set.user) || {}
		opsetMember = _.clone(object.permission_set.member) || {}
		opsetGuest = _.clone(object.permission_set.guest) || {}

		opsetSupplier = _.clone(object.permission_set.supplier) || {}
		opsetCustomer = _.clone(object.permission_set.customer) || {}

		# sharedListViews = Creator.getCollection('object_listviews').find({space: spaceId, object_name: object_name, shared: true}, {fields:{_id:1}}).fetch()
		# sharedListViews = _.pluck(sharedListViews,"_id")
		# if sharedListViews.length
		# 	unless opsetAdmin.list_views
		# 		opsetAdmin.list_views = []
		# 	opsetAdmin.list_views = _.union opsetAdmin.list_views, sharedListViews
		# 	unless opsetUser.list_views
		# 		opsetUser.list_views = []
		# 	opsetUser.list_views = _.union opsetUser.list_views, sharedListViews
		# 数据库中如果配置了默认的admin/user权限集设置，应该覆盖代码中admin/user的权限集设置
		if psetsAdmin
			posAdmin = findOne_permission_object(psetsAdmin_pos, object_name, psetsAdmin._id)
			if posAdmin
				opsetAdmin.allowCreate = posAdmin.allowCreate
				opsetAdmin.allowDelete = posAdmin.allowDelete
				opsetAdmin.allowEdit = posAdmin.allowEdit
				opsetAdmin.allowRead = posAdmin.allowRead
				opsetAdmin.modifyAllRecords = posAdmin.modifyAllRecords
				opsetAdmin.viewAllRecords = posAdmin.viewAllRecords
				opsetAdmin.modifyCompanyRecords = posAdmin.modifyCompanyRecords
				opsetAdmin.viewCompanyRecords = posAdmin.viewCompanyRecords
				opsetAdmin.disabled_list_views = posAdmin.disabled_list_views
				opsetAdmin.disabled_actions = posAdmin.disabled_actions
				opsetAdmin.unreadable_fields = posAdmin.unreadable_fields
				opsetAdmin.uneditable_fields = posAdmin.uneditable_fields
				opsetAdmin.unrelated_objects = posAdmin.unrelated_objects
				opsetAdmin.uneditable_related_list = posAdmin.uneditable_related_list
		if psetsUser
			posUser = findOne_permission_object(psetsUser_pos, object_name, psetsUser._id)
			if posUser
				opsetUser.allowCreate = posUser.allowCreate
				opsetUser.allowDelete = posUser.allowDelete
				opsetUser.allowEdit = posUser.allowEdit
				opsetUser.allowRead = posUser.allowRead
				opsetUser.modifyAllRecords = posUser.modifyAllRecords
				opsetUser.viewAllRecords = posUser.viewAllRecords
				opsetUser.modifyCompanyRecords = posUser.modifyCompanyRecords
				opsetUser.viewCompanyRecords = posUser.viewCompanyRecords
				opsetUser.disabled_list_views = posUser.disabled_list_views
				opsetUser.disabled_actions = posUser.disabled_actions
				opsetUser.unreadable_fields = posUser.unreadable_fields
				opsetUser.uneditable_fields = posUser.uneditable_fields
				opsetUser.unrelated_objects = posUser.unrelated_objects
				opsetUser.uneditable_related_list = posUser.uneditable_related_list
		if psetsMember
			posMember = findOne_permission_object(psetsMember_pos, object_name, psetsMember._id)
			if posMember
				opsetMember.allowCreate = posMember.allowCreate
				opsetMember.allowDelete = posMember.allowDelete
				opsetMember.allowEdit = posMember.allowEdit
				opsetMember.allowRead = posMember.allowRead
				opsetMember.modifyAllRecords = posMember.modifyAllRecords
				opsetMember.viewAllRecords = posMember.viewAllRecords
				opsetMember.modifyCompanyRecords = posMember.modifyCompanyRecords
				opsetMember.viewCompanyRecords = posMember.viewCompanyRecords
				opsetMember.disabled_list_views = posMember.disabled_list_views
				opsetMember.disabled_actions = posMember.disabled_actions
				opsetMember.unreadable_fields = posMember.unreadable_fields
				opsetMember.uneditable_fields = posMember.uneditable_fields
				opsetMember.unrelated_objects = posMember.unrelated_objects
				opsetMember.uneditable_related_list = posMember.uneditable_related_list
		if psetsGuest
			posGuest = findOne_permission_object(psetsGuest_pos, object_name, psetsGuest._id)
			if posGuest
				opsetGuest.allowCreate = posGuest.allowCreate
				opsetGuest.allowDelete = posGuest.allowDelete
				opsetGuest.allowEdit = posGuest.allowEdit
				opsetGuest.allowRead = posGuest.allowRead
				opsetGuest.modifyAllRecords = posGuest.modifyAllRecords
				opsetGuest.viewAllRecords = posGuest.viewAllRecords
				opsetGuest.modifyCompanyRecords = posGuest.modifyCompanyRecords
				opsetGuest.viewCompanyRecords = posGuest.viewCompanyRecords
				opsetGuest.disabled_list_views = posGuest.disabled_list_views
				opsetGuest.disabled_actions = posGuest.disabled_actions
				opsetGuest.unreadable_fields = posGuest.unreadable_fields
				opsetGuest.uneditable_fields = posGuest.uneditable_fields
				opsetGuest.unrelated_objects = posGuest.unrelated_objects
				opsetGuest.uneditable_related_list = posGuest.uneditable_related_list
		if psetsSupplier
			posSupplier = findOne_permission_object(psetsSupplier_pos, object_name, psetsSupplier._id);
			if posSupplier
				opsetSupplier.allowCreate = posSupplier.allowCreate
				opsetSupplier.allowDelete = posSupplier.allowDelete
				opsetSupplier.allowEdit = posSupplier.allowEdit
				opsetSupplier.allowRead = posSupplier.allowRead
				opsetSupplier.modifyAllRecords = posSupplier.modifyAllRecords
				opsetSupplier.viewAllRecords = posSupplier.viewAllRecords
				opsetSupplier.modifyCompanyRecords = posSupplier.modifyCompanyRecords
				opsetSupplier.viewCompanyRecords = posSupplier.viewCompanyRecords
				opsetSupplier.disabled_list_views = posSupplier.disabled_list_views
				opsetSupplier.disabled_actions = posSupplier.disabled_actions
				opsetSupplier.unreadable_fields = posSupplier.unreadable_fields
				opsetSupplier.uneditable_fields = posSupplier.uneditable_fields
				opsetSupplier.unrelated_objects = posSupplier.unrelated_objects
				opsetSupplier.uneditable_related_list = posSupplier.uneditable_related_list
		if psetsCustomer
			posCustomer = findOne_permission_object(psetsCustomer_pos, object_name, psetsCustomer._id);
			if posCustomer
				opsetCustomer.allowCreate = posCustomer.allowCreate
				opsetCustomer.allowDelete = posCustomer.allowDelete
				opsetCustomer.allowEdit = posCustomer.allowEdit
				opsetCustomer.allowRead = posCustomer.allowRead
				opsetCustomer.modifyAllRecords = posCustomer.modifyAllRecords
				opsetCustomer.viewAllRecords = posCustomer.viewAllRecords
				opsetCustomer.modifyCompanyRecords = posCustomer.modifyCompanyRecords
				opsetCustomer.viewCompanyRecords = posCustomer.viewCompanyRecords
				opsetCustomer.disabled_list_views = posCustomer.disabled_list_views
				opsetCustomer.disabled_actions = posCustomer.disabled_actions
				opsetCustomer.unreadable_fields = posCustomer.unreadable_fields
				opsetCustomer.uneditable_fields = posCustomer.uneditable_fields
				opsetCustomer.unrelated_objects = posCustomer.unrelated_objects
				opsetCustomer.uneditable_related_list = posCustomer.uneditable_related_list

		if !userId
			permissions = opsetAdmin
		else
			if isSpaceAdmin
				permissions = opsetAdmin
			else
				if spaceId is 'common'
					permissions = opsetUser
				else
					spaceUser = if _.isNull(this.spaceUser) or this.spaceUser then this.spaceUser else Creator.getCollection("space_users").findOne({ space: spaceId, user: userId }, { fields: { profile: 1 } })
					if spaceUser
						prof = spaceUser.profile
						if prof
							if prof is 'user'
								permissions = opsetUser
							else if prof is 'member'
								permissions = opsetMember
							else if prof is 'guest'
								permissions = opsetGuest
							else if prof is 'supplier'
								permissions = opsetSupplier
							else if prof is 'customer'
								permissions = opsetCustomer
						else # 没有profile则认为是user权限
							permissions = opsetUser
					else
						permissions = opsetGuest
		if psets.length > 0
			set_ids = _.pluck psets, "_id"
			pos = find_permission_object(psetsCurrent_pos, object_name, set_ids)
			pos = unionPermissionObjects(pos, object, psets)
			_.each pos, (po)->
				if po.permission_set_id == psetsAdmin?._id or 
				po.permission_set_id == psetsUser?._id or 
				po.permission_set_id == psetsMember?._id or 
				po.permission_set_id == psetsGuest?._id or
				po.permission_set_id == psetsSupplier?._id or
				po.permission_set_id == psetsCustomer?._id
					# 默认的admin/user权限值只实行上面的默认值覆盖，不做算法判断
					return
				if _.isEmpty(permissions)
					permissions = po
				if po.allowRead
					permissions.allowRead = true
				if po.allowCreate
					permissions.allowCreate = true
				if po.allowEdit
					permissions.allowEdit = true
				if po.allowDelete
					permissions.allowDelete = true
				if po.modifyAllRecords
					permissions.modifyAllRecords = true
				if po.viewAllRecords
					permissions.viewAllRecords = true
				if po.modifyCompanyRecords
					permissions.modifyCompanyRecords = true
				if po.viewCompanyRecords
					permissions.viewCompanyRecords = true

				permissions.disabled_list_views = intersectionPlus(permissions.disabled_list_views, po.disabled_list_views)
				permissions.disabled_actions = intersectionPlus(permissions.disabled_actions, po.disabled_actions)
				permissions.unreadable_fields = intersectionPlus(permissions.unreadable_fields, po.unreadable_fields)
				permissions.uneditable_fields = intersectionPlus(permissions.uneditable_fields, po.uneditable_fields)
				permissions.unrelated_objects = intersectionPlus(permissions.unrelated_objects, po.unrelated_objects)
				permissions.uneditable_related_list = intersectionPlus(permissions.uneditable_related_list, po.uneditable_related_list)
		
		if object.is_view
			permissions.allowCreate = false
			permissions.allowEdit = false
			permissions.allowDelete = false
			permissions.modifyAllRecords = false
			permissions.modifyCompanyRecords = false
			permissions.disabled_actions = []
		Creator.processPermissions permissions

		if object.permission_set.owner
			permissions.owner = object.permission_set.owner
		return permissions


	# Creator.initPermissions = (object_name) ->

		# # 应该把计算出来的
		# Creator.Collections[object_name].allow
		# 	insert: (userId, doc) ->
		# 		if !userId
		# 			return false
		# 		if !doc.space
		# 			return false
	    	# 		permissions = Creator.getObjectPermissions(doc.space, userId, object_name)
		# 		if !permissions.allowCreate
		# 			return false

		# 		return true
		# 	update: (userId, doc) ->
		# 		if !userId
		# 			return false
		# 		if !doc.space
		# 			return false
		# 		permissions = Creator.getObjectPermissions(doc.space, userId, object_name)
		# 		if !permissions.allowEdit
		# 			return false
		# 		return true
		# 	remove: (userId, doc) ->
		# 		if !userId
		# 			return false
		# 		if !doc.space
		# 			return false
		# 		permissions = Creator.getObjectPermissions(doc.space, userId, object_name)
		# 		if !permissions.allowDelete
		# 			return false
		# 		return true

	Meteor.methods
		# Calculate Permissions on Server
		"creator.object_permissions": (spaceId)->
			return Creator.getAllPermissions(spaceId, this.userId)
