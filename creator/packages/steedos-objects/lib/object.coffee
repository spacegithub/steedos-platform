clone = require('clone');
Creator.objectsByName = {}   # 此对象只能在确保所有Object初始化完成后调用， 否则获取到的object不全

Creator.formatObjectName = (object_name)->
	if object_name.startsWith('cfs.files.')
		object_name = object_name.replace(new RegExp('\\.', 'g'), '_')
	return object_name

Creator.Object = (options)->
	_baseObject = Creator.baseObject
	if Meteor.isClient
		_baseObject = {actions: Creator.baseObject.actions , fields: {}, triggers: {}, permission_set: {}}
	self = this
	if (!options.name)
		console.error(options)
		throw new Error('Creator.Object options must specify name');

	self._id = options._id || options.name
	self.space = options.space
	self.name = options.name
	self.label = options.label
	self.icon = options.icon
	self.description = options.description
	self.is_view = options.is_view
	self.form = options.form
	self.relatedList = options.relatedList
	if !_.isBoolean(options.is_enable)  || options.is_enable == true
		self.is_enable = true
	else
		self.is_enable = false
	if Meteor.isClient
		if _.has(options, 'allow_actions')
			self.allow_actions = options.allow_actions
		if _.has(options, 'allow_relatedList')
			self.allow_relatedList = options.allow_relatedList
	self.enable_search = options.enable_search
	self.enable_files = options.enable_files
	self.enable_tasks = options.enable_tasks
	self.enable_notes = options.enable_notes
	self.enable_audit = options.enable_audit
	if options.paging
		self.paging = options.paging
	self.hidden = options.hidden
	self.enable_api = (options.enable_api == undefined) or options.enable_api
	self.custom = options.custom
	self.enable_share = options.enable_share
	self.enable_instances = options.enable_instances
	self.enable_process = options.enable_process
	if Meteor.isClient
		if Creator.isCloudAdminSpace(Session.get("spaceId"))
			self.enable_tree = false
		else
			self.enable_tree = options.enable_tree
			self.sidebar = _.clone(options.sidebar)
	else
		self.sidebar = _.clone(options.sidebar)
		self.enable_tree = options.enable_tree
	self.open_window = options.open_window
	self.filter_company = options.filter_company
	self.calendar = _.clone(options.calendar)
	self.enable_chatter = options.enable_chatter
	self.enable_trash = options.enable_trash
	self.enable_space_global = options.enable_space_global
	self.enable_approvals = options.enable_approvals
	self.enable_follow = options.enable_follow
	self.enable_workflow = options.enable_workflow
	self.enable_inline_edit = options.enable_inline_edit
	if _.has(options, 'in_development')
		self.in_development = options.in_development
	self.idFieldName = '_id'
	if options.database_name
		self.database_name = options.database_name
	if (!options.fields)
		console.error(options)
		throw new Error('Creator.Object options must specify fields');

	self.fields = clone(options.fields)

	_.each self.fields, (field, field_name)->
		if field.is_name
			self.NAME_FIELD_KEY = field_name
		else if field_name == 'name' && !self.NAME_FIELD_KEY
			self.NAME_FIELD_KEY = field_name
		if field.primary
			self.idFieldName = field_name
		if Meteor.isClient
			if Creator.isCloudAdminSpace(Session.get("spaceId"))
				if field_name == 'space'
					field.filterable = true
					field.hidden = false

	if !options.database_name || options.database_name == 'meteor-mongo'
		_.each _baseObject.fields, (field, field_name)->
			if !self.fields[field_name]
				self.fields[field_name] = {}
			self.fields[field_name] = _.extend(_.clone(field), self.fields[field_name])

	_.each self.fields, (field, field_name)->
		if field.type == 'autonumber'
			field.readonly = true
		else if field.type == 'formula'
			field.readonly = true
		else if field.type == 'summary'
			field.readonly = true

	self.list_views = {}
	defaultView = Creator.getObjectDefaultView(self.name)
	_.each options.list_views, (item, item_name)->
		oitem = Creator.convertListView(defaultView, item, item_name)
		self.list_views[item_name] = oitem

	self.triggers = _.clone(_baseObject.triggers)
	_.each options.triggers, (item, item_name)->
		if !self.triggers[item_name]
			self.triggers[item_name] = {}
		self.triggers[item_name].name = item_name
		self.triggers[item_name] = _.extend(_.clone(self.triggers[item_name]), item)

	self.actions = _.clone(_baseObject.actions)
	_.each options.actions, (item, item_name)->
		if !self.actions[item_name]
			self.actions[item_name] = {}
		copyItem = _.clone(self.actions[item_name])
		delete self.actions[item_name] #先删除相关属性再重建才能保证后续重复定义的属性顺序生效
		self.actions[item_name] = _.extend(copyItem, item)

	_.each self.actions, (item, item_name)->
		item.name = item_name

	self.related_objects = Creator.getObjectRelateds(self.name)

	# 让所有object默认有所有list_views/actions/related_objects/readable_fields/editable_fields完整权限，该权限可能被数据库中设置的admin/user权限覆盖
	self.permission_set = _.clone(_baseObject.permission_set)
	# defaultListViews = _.keys(self.list_views)
	# defaultActions = _.keys(self.actions)
	# defaultRelatedObjects = _.pluck(self.related_objects,"object_name")
	# defaultReadableFields = []
	# defaultEditableFields = []
	# _.each self.fields, (field, field_name)->
	# 	if !(field.hidden)    #231 omit字段支持在非编辑页面查看, 因此删除了此处对omit的判断
	# 		defaultReadableFields.push field_name
	# 		if !field.readonly
	# 			defaultEditableFields.push field_name

	# _.each self.permission_set, (item, item_name)->
	# 	if item_name == "none"
	# 		return
	# 	if self.list_views
	# 		self.permission_set[item_name].list_views = defaultListViews
	# 	if self.actions
	# 		self.permission_set[item_name].actions = defaultActions
	# 	if self.related_objects
	# 		self.permission_set[item_name].related_objects = defaultRelatedObjects
	# 	if self.fields
	# 		self.permission_set[item_name].readable_fields = defaultReadableFields
	# 		self.permission_set[item_name].editable_fields = defaultEditableFields
	unless options.permission_set
		options.permission_set = {}
	if !(options.permission_set?.admin)
		options.permission_set.admin = _.clone(self.permission_set["admin"])
	if !(options.permission_set?.user)
		options.permission_set.user = _.clone(self.permission_set["user"])
	_.each options.permission_set, (item, item_name)->
		if !self.permission_set[item_name]
			self.permission_set[item_name] = {}
		self.permission_set[item_name] = _.extend(_.clone(self.permission_set[item_name]), item)

	# 前端根据permissions改写field相关属性，后端只要走默认属性就行，不需要改写
	if Meteor.isClient
		permissions = options.permissions
		disabled_list_views = permissions?.disabled_list_views
		if disabled_list_views?.length
			defaultListViewId = options.list_views?.all?._id
			if defaultListViewId
				# 把视图权限配置中默认的all视图id转换成all关键字
				permissions.disabled_list_views = _.map disabled_list_views, (list_view_item) ->
					return if defaultListViewId == list_view_item then "all" else list_view_item
		self.permissions = new ReactiveVar(permissions)
#		_.each self.fields, (field, field_name)->
#			if field
#				if _.indexOf(permissions?.unreadable_fields, field_name) < 0
#					if field.hidden
#						return
#					if _.indexOf(permissions?.uneditable_fields, field_name) > -1
#						field.readonly = true
#						field.disabled = true
#						# 当只读时，如果不去掉必填字段，autoform是会报错的
#						field.required = false
#				else
#					field.hidden = true
	else
		self.permissions = null

	_db = Creator.createCollection(options)

	Creator.Collections[_db._name] = _db

	self.db = _db

	self._collection_name = _db._name

	schema = Creator.getObjectSchema(self)
	self.schema = new SimpleSchema(schema)
	if self.name != "users" and self.name != "cfs.files.filerecord" && !self.is_view && !_.contains(["flows", "forms", "instances", "organizations", "action_field_updates"], self.name)
		if Meteor.isClient
			_db.attachSchema(self.schema, {replace: true})
		else
			_db.attachSchema(self.schema, {replace: true})
	if self.name == "users"
		_db._simpleSchema = self.schema

	if _.contains(["flows", "forms", "instances", "organizations"], self.name)
		if Meteor.isClient
			_db.attachSchema(self.schema, {replace: true})

	Creator.objectsByName[self._collection_name] = self

	return self

# Creator.Object.prototype.i18n = ()->
# 	# set object label
# 	self = this

# 	key = self.name
# 	if t(key) == key
# 		if !self.label
# 			self.label = self.name
# 	else
# 		self.label = t(key)

# 	# set field labels
# 	_.each self.fields, (field, field_name)->
# 		fkey = self.name + "_" + field_name
# 		if t(fkey) == fkey
# 			if !field.label
# 				field.label = field_name
# 		else
# 			field.label = t(fkey)
# 		self.schema?._schema?[field_name]?.label = field.label


# 	# set listview labels
# 	_.each self.list_views, (item, item_name)->
# 		i18n_key = self.name + "_listview_" + item_name
# 		if t(i18n_key) == i18n_key
# 			if !item.label
# 				item.label = item_name
# 		else
# 			item.label = t(i18n_key)


Creator.getObjectODataRouterPrefix = (object)->
	if object
		if !object.database_name || object.database_name == 'meteor-mongo'
			return "/api/odata/v4"
		else
			return "/api/odata/#{object.database_name}"

# if Meteor.isClient

# 	Meteor.startup ->
# 		Tracker.autorun ->
# 			if Session.get("steedos-locale") && Creator.bootstrapLoaded?.get()
# 				_.each Creator.objectsByName, (object, object_name)->
# 					object.i18n()

Meteor.startup ->
	if !Creator.bootstrapLoaded && Creator.Objects
		_.each Creator.Objects, (object)->
			new Creator.Object(object)

