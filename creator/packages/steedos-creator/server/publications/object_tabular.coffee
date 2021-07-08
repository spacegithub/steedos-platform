Meteor.publishComposite "steedos_object_tabular", (tableName, ids, fields, spaceId)->
	unless this.userId
		return this.ready()

	check(tableName, String);
	check(ids, Array);
	check(fields, Match.Optional(Object));

	_object_name = tableName.replace("creator_","")
	_object = Creator.getObject(_object_name, spaceId)

	if spaceId
		_object_name = Creator.getObjectName(_object)

	object_colleciton = Creator.getCollection(_object_name)


	_fields = _object?.fields
	if !_fields || !object_colleciton
		return this.ready()

	reference_fields = _.filter _fields, (f)->
		return _.isFunction(f.reference_to) || !_.isEmpty(f.reference_to)

	self = this

	self.unblock();

	if reference_fields.length > 0
		data = {
			find: ()->
				self.unblock();
				field_keys = {}
				_.each _.keys(fields), (f)->
					unless /\w+(\.\$){1}\w?/.test(f)
						field_keys[f] = 1
				
				return object_colleciton.find({_id: {$in: ids}}, {fields: field_keys});
		}

		data.children = []

		keys = _.keys(fields)

		if keys.length < 1
			keys = _.keys(_fields)

		_keys = []

		keys.forEach (key)->
			if _object.schema._objectKeys[key + '.']
				_keys = _keys.concat(_.map(_object.schema._objectKeys[key + '.'], (k)->
					return key + '.' + k
				))
			_keys.push(key)

		_keys.forEach (key)->
			reference_field = _fields[key]

			if reference_field && (_.isFunction(reference_field.reference_to) || !_.isEmpty(reference_field.reference_to))  # and Creator.Collections[reference_field.reference_to]
				data.children.push {
					find: (parent) ->
						try
							self.unblock();

							query = {}

							# 表格子字段特殊处理
							if /\w+(\.\$\.){1}\w+/.test(key)
								p_k = key.replace(/(\w+)\.\$\.\w+/ig, "$1")
								s_k = key.replace(/\w+\.\$\.(\w+)/ig, "$1")
								reference_ids = parent[p_k].getProperty(s_k)
							else
								reference_ids = key.split('.').reduce (o, x) ->
										o?[x]
								, parent

							reference_to = reference_field.reference_to

							if _.isFunction(reference_to)
								reference_to = reference_to()

							if _.isArray(reference_to)
								if _.isObject(reference_ids) && !_.isArray(reference_ids)
									reference_to = reference_ids.o
									reference_ids = reference_ids.ids || []
								else
									return []

							if _.isArray(reference_ids)
								query._id = {$in: reference_ids}
							else
								query._id = reference_ids

							reference_to_object = Creator.getObject(reference_to, spaceId)

							name_field_key = reference_to_object.NAME_FIELD_KEY

							children_fields = {_id: 1, space: 1}

							if name_field_key
								children_fields[name_field_key] = 1

							return Creator.getCollection(reference_to, spaceId).find(query, {
								fields: children_fields
							});
						catch e
							console.log(reference_to, parent, e)
							return []
				}

		return data
	else
		return {
			find: ()->
				self.unblock();
				return object_colleciton.find({_id: {$in: ids}}, {fields: fields})
		};

