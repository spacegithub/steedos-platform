# Variables
# - this.object_name
# - this.field_name
# - this.field
# - this.doc
# - this._id

Template.creator_table_cell.onRendered ->
	self = this
	self.autorun ->
		_field = self.data.field
		object_name = self.data.object_name
		this_object = Creator.getObject(object_name)
		record_id = self.data._id
#		record = Creator.getCollection(object_name).findOne(record_id)
		# record = self.data.doc
		# 这里不可以用self.data.doc，因为当编辑记录后保存时，不能触发autorun再进入
		record = Template.creator_view.currentInstance?.record.get()
		unless record
			record = self.data.doc
		if record
			if  _field?.type == "grid"
				val = _field.name.split('.').reduce (o, x) ->
								o[x]
						, record

				columns = Creator.getSchema(object_name)._objectKeys[_field.name + ".$."]

				columns = _.map columns, (column)->
					field = this_object.fields[_field.name + ".$." + column]
					if field.hidden
						return undefined
					columnItem =
						cssClass: "slds-cell-edit"
						caption: field.label || column
						dataField: column
						alignment: "left"
						cellTemplate: (container, options) ->
							field_name = _field.name + ".$." + column
							field_name = field_name.replace(/\$\./,"")
							cellOption = {_id: options.data._id, val: options.data[column], record_val: record, doc: options.data, field: field, field_name: field_name, object_name:object_name, hideIcon: true, is_detail_view: true}
							Blaze.renderWithData Template.creator_table_cell, cellOption, container[0]
					return columnItem

				columns = _.compact(columns)
				module.dynamicImport('devextreme/ui/data_grid').then (dxDataGrid)->
					DevExpress.ui.dxDataGrid = dxDataGrid;
					self.$(".cellGridContainer").dxDataGrid
						dataSource: val,
						columns: columns
						showColumnLines: false
						showRowLines: true
						height: "auto"
		
		# 显示额外的其他字段
		if _field.name == "created_by"
			_field.extra_field = "created"
		else if _field.name == "modified_by"
			_field.extra_field = "modified"
		extra_field = _field?.extra_field
		if extra_field and self.data.is_detail_view
			extraContainer = self.$(".cell-extra-field-container")
			unless extraContainer.find(".creator_table_cell").length
				currentDoc = self.data.doc
				unless currentDoc
					return
				if extra_field.indexOf(".") > 0
					# 子表字段取值
					extraKeys = extra_field.split(".")
					extraFirstLevelValue = currentDoc[extraKeys[0]]
					extraVal = extraFirstLevelValue[extraKeys[1]]
				else
					extraVal = currentDoc[extra_field]
				cellOption = {_id: currentDoc._id, val: extraVal, doc: currentDoc, field: this_object.fields[extra_field], field_name: extra_field, object_name:object_name, hideIcon: true, is_detail_view: true}
				if cellOption.field
					Blaze.renderWithData Template.creator_table_cell, cellOption, extraContainer[0]

Template.creator_table_cell.helpers Creator.helpers

Template.creator_table_cell.helpers
	openWindow: ()->
		if Steedos.isMobile()
			return false
		# if Template.instance().data?.open_window || Template.instance().data?.is_related
		# data?.is_related应该是标识`/app/contracts/contracts/EzxhPBf9k9eR5qjqs/contract_receipts/grid`这样的列表主字段链接
		if Template.instance().data?.open_window
			return true
		object_name = this.object_name
		this_object = Creator.getObject(object_name)
		# if this_object?.open_window == true || this.reference_to # 所有的相关链接 改为弹出新窗口 #735
		# this.reference_to应该是所有相关项的标识
		if this_object?.open_window == true
			return true
		else
			return false
	
	itemActionName: ()->
		data = Template.instance().data
		unless data
			return null
		object_name = data.object_name
		isFieldName = data.field_name == Creator.getObject(object_name).NAME_FIELD_KEY
		if object_name == "cms_files" and isFieldName
			return "download"
		else
			return null

	cellData: ()->
		return Creator.getTableCellData(this)
	
	selectCellColorClass: (data)->
		if data.field?.type == "select"
			result = "creator-cell-color-#{data.object_name}-#{data.field.name} creator-cell-color-#{data.object_name}-#{data.field.name}-#{this.value}"
			if data.field?.multiple
				result += " creator-cell-multiple-color"
			return result
	editable: ()->
		obj = Creator.getObject(this.object_name)
		if !obj
			return false
		if obj.enable_inline_edit == false
			return false
		if !this.field
			return false
		safeField = Creator.getRecordSafeField(this.field, this.doc, this.object_name);
		if !safeField
			return false
		if safeField.omit or safeField.readonly
			return false

		if safeField.type == "filesize"
			return false

		if safeField.name == '_id'
			return false

		permission = Creator.getRecordPermissions(this.object_name, this.doc, Meteor.userId())
		if !permission.allowEdit
			return false

		return true

	showEditIcon: ()->
		if this.hideIcon
			return false
		return true

	isMarkdown: (type)->
		return type is "markdown"

	isType: (type) ->
		return this.type is type

	fieldDataType: () ->
		return this.field.data_type || this.field.type

	isExtraField: () ->
		fieldName = this.field?.name
		return fieldName == "created_by" or fieldName == "modified_by"
	eidtIconName: (editable) ->
		return if editable then 'edit' else 'lock'
	eidtIconClassName: (editable) ->
		return if editable then 'slds-button__icon_hint slds-button__icon_edit' else 'slds-button__icon_hint slds-button__icon_lock'


Template.creator_table_cell.events

	'click .list-item-link-action': (event, template) ->
		data = template.data
		unless data
			return false
		objectName = data.object_name
		recordId = data._id
		# name字段链接点击时执行相应action，而不是默认的进入详细界面
		actionName = event.currentTarget.dataset.actionName
		action = Creator.getActions(objectName).find (n)->
			return n.name == actionName
		unless action
			return false
		Creator.executeAction(objectName, action, recordId)