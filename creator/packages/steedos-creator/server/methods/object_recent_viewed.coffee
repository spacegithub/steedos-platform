Meteor.methods
	"object_recent_viewed": (object_name, record_id, space_id)->
		if !this.userId
			return null

		if object_name == "object_recent_viewed"
			return
		if object_name and record_id
			if !space_id
				doc = Creator.getCollection(object_name).findOne({_id: record_id}, {fields: {space: 1}})
				space_id = doc?.space

			collection_recent_viewed = Creator.getCollection("object_recent_viewed")
			filters = { owner: this.userId, space: space_id, 'record.o': object_name, 'record.ids': [record_id]}
			current_recent_viewed = collection_recent_viewed.findOne(filters)
			if current_recent_viewed
				collection_recent_viewed.update(
					current_recent_viewed._id,
					{
						$inc: {
							count: 1
						},
						$set: {
							modified: new Date()
							modified_by: this.userId
						}
					}
				)
			else
				collection_recent_viewed.insert(
					{
						_id: collection_recent_viewed._makeNewID()
						owner: this.userId
						space: space_id
						record: {o: object_name, ids: [record_id]}
						count: 1
						created: new Date()
						created_by: this.userId
						modified: new Date()
						modified_by: this.userId
					}
				)
			return