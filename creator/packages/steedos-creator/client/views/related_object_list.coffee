getRelatedListTemplateId = ()->
	return "steedos-list-related-object-list"

Template.related_object_list.helpers
	related_object_name: ()->
		return Session.get("related_object_name")

	related_object_label: ()->
		related_object_name = Session.get("related_object_name")
		relatedList = Creator.getRelatedList(Session.get("object_name"), Session.get("record_id"))
		relatedObj = _.find relatedList, (rl) ->
			return rl.object_name == related_object_name
		return relatedObj?.label || Creator.getObject(related_object_name).label

	is_file: ()->
		return Session.get("related_object_name") == "cms_files"

	object_label: ()->
		object_name = Session.get "object_name"
		return Creator.getObject(object_name).label
	
	record_name: ()->
		object_name = Session.get "object_name"
		name_field_key = Creator.getObject(object_name).NAME_FIELD_KEY
		return Template.instance()?.record.get()[name_field_key]

	record_url: ()->
		object_name = Session.get "object_name"
		record_id = Session.get "record_id"
		return Creator.getObjectUrl(object_name, record_id)

	allowCreate: ()->
		object_name = Session.get "object_name"
		related_object_name = Session.get "related_object_name"
		if related_object_name == object_name
			# 说明是进入了已经新建成功的详细界面，此时会因为Session再进入该函数，不再需要处理
			return false
		relatedList = Creator.getRelatedList(object_name, Session.get("record_id"))
		related_list_item_props = relatedList.find((item)-> return item.object_name == related_object_name)
		return Creator.getRecordRelatedListPermissions(object_name, related_list_item_props).allowCreate

	isUnlocked: ()->
		if Creator.getPermissions(Session.get('object_name')).modifyAllRecords
			return true
		record = Creator.getObjectRecord()
		return !record?.locked

	hasPermission: (permissionName)->
		permissions = Creator.getPermissions()
		if permissions
			return permissions[permissionName]

	recordsTotalCount: ()->
		return Template.instance().recordsTotal.get()
	
	list_data: () ->
		object_name = Session.get "object_name"
		relatedList = Creator.getRelatedList(Session.get("object_name"), Session.get("record_id"))
		related_object_name = Session.get "related_object_name"
		related_list_item_props = relatedList.find((item)-> return item.object_name == related_object_name)
		data = {
			id: getRelatedListTemplateId(), 
			related_object_name: related_object_name, 
			object_name: object_name, 
			total: Template.instance().recordsTotal, 
			is_related: true, 
			related_list_item_props: related_list_item_props,
			pageSize: 50
		}
		if object_name == 'objects'
			data.record_id = Template.instance()?.record.get().name;
		return data


Template.related_object_list.events
	"click .add-related-object-record": (event, template)->
		related_object_name = Session.get "related_object_name"
		object_name = Session.get "object_name"
		record_id = Session.get "record_id"
		if object_name == 'objects'
			record_id = template?.record?.get().name;
		action_collection_name = Creator.getObject(related_object_name).label
		
		ids = Creator.TabularSelectedIds[related_object_name]
		if ids?.length
			# 列表有选中项时，取第一个选中项，复制其内容到新建窗口中
			# 这的第一个指的是第一次勾选的选中项，而不是列表中已勾选的第一项
			record_id = ids[0]
			doc = Creator.odata.get(related_object_name, record_id)
			Session.set 'cmDoc', doc
			# “保存并新建”操作中自动打开的新窗口中需要再次复制最新的doc内容到新窗口中
			Session.set 'cmShowAgainDuplicated', true
		else 
			defaultDoc = FormManager.getRelatedInitialValues(object_name, record_id, related_object_name);
			if !_.isEmpty(defaultDoc)
				Session.set 'cmDoc', defaultDoc
		
		Session.set "action_collection", "Creator.Collections.#{related_object_name}"
		Session.set "action_collection_name", action_collection_name
		Session.set("action_save_and_insert", false)
		Meteor.defer ->
			$(".creator-add").click()

	'click .btn-refresh': (event, template)->
		if Steedos.isMobile()
			Template.list.refresh getRelatedListTemplateId()
		else
			dxDataGridInstance = $(event.currentTarget).closest(".related_object_list").find(".gridContainer").dxDataGrid().dxDataGrid('instance')
			Template.creator_grid.refresh(dxDataGridInstance)

	'change .input-file-upload': (event, template)->
		Creator.relatedObjectFileUploadHandler event, ()->
			if Steedos.isMobile()
				Template.list.refresh getRelatedListTemplateId()
			else
				dataset = event.currentTarget.dataset
				parent = dataset?.parent
				targetObjectName = dataset?.targetObjectName
				gridContainerWrap = $(event.currentTarget).closest(".related_object_list")
				dxDataGridInstance = gridContainerWrap.find(".gridContainer.#{targetObjectName}").dxDataGrid().dxDataGrid('instance')
				Template.creator_grid.refresh dxDataGridInstance


Template.related_object_list.onCreated ->
	this.recordsTotal = new ReactiveVar(0)
	this.record = new ReactiveVar({});
	object_name = Session.get "object_name"
	record_id = Session.get "record_id"
	self = this
	this.autorun ()->
		_record = Creator.getCollection(object_name).findOne(record_id)
		if !_record
			_record = Creator.odata.get(object_name, record_id)
		self.record.set( _record || {})

