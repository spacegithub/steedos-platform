Meteor.methods({
	cc_do: function (approve, cc_user_ids, description) {

		var setObj = {};
		var ins_id = approve.instance;
		var trace_id = approve.trace;
		var approve_id = approve._id;
		var instance = db.instances.findOne(ins_id, {
			fields: {
				space: 1,
				traces: 1,
				cc_users: 1,
				values: 1
			}
		});
		var current_user_id = this.userId;
		var space_id = instance.space;
		var new_approves = [];

		var from_user_name = db.users.findOne(current_user_id, {
			fields: {
				name: 1
			}
		}).name

		cc_user_ids.forEach(function (userId, idx) {
			var user = db.users.findOne(userId, {
				fields: {
					name: 1
				}
			});
			var space_user = db.space_users.findOne({
				space: space_id,
				user: userId
			}, {
				fields: {
					organization: 1
				}
			});
			var org_id = space_user.organization;
			var organization = db.organizations.findOne(org_id, {
				fields: {
					name: 1,
					fullname: 1
				}
			});
			var agent = uuflowManager.getAgent(space_id, userId);
			var handler_id = userId;
			var handler_info = user;
			var handler_space_user = space_user;
			var handler_org_info = organization;
			if (agent) {
				handler_id = agent;
				handler_info = db.users.findOne(agent, {
					fileds: {
						name: 1
					}
				});
				handler_space_user = uuflowManager.getSpaceUser(space_id, agent);
				handler_org_info = uuflowManager.getSpaceUserOrgInfo(handler_space_user);
				cc_user_ids[idx] = agent;
			}
			var appr = {
				'_id': new Mongo.ObjectID()._str,
				'instance': ins_id,
				'trace': trace_id,
				'is_finished': false,
				'user': userId,
				'user_name': user.name,
				'handler': handler_id,
				'handler_name': handler_info.name,
				'handler_organization': handler_space_user.organization,
				'handler_organization_name': handler_org_info.name,
				'handler_organization_fullname': handler_org_info.fullname,
				'type': 'cc',
				'start_date': new Date(),
				'is_read': false,
				'from_user': current_user_id,
				'from_user_name': from_user_name,
				'opinion_fields_code': approve.opinion_fields_code,
				'sign_field_code': (approve.opinion_fields_code && approve.opinion_fields_code.length == 1) ? approve.opinion_fields_code[0] : "",
				'from_approve_id': approve_id,
				'cc_description': description
			};
			if (agent) {
				appr.agent = agent;
			}
			uuflowManager.setRemindInfo(instance.values, appr)
			new_approves.push(appr);
		})


		setObj.modified = new Date();
		setObj.modified_by = this.userId;

		db.instances.update({
			_id: ins_id,
			'traces._id': trace_id
		}, {
			$set: setObj,
			$addToSet: {
				'traces.$.approves': {
					$each: new_approves
				}
			},
			$push: {
				cc_users: {
					$each: cc_user_ids
				}
			}
		});

		instance = db.instances.findOne(ins_id);
		current_user_info = db.users.findOne(current_user_id);
		pushManager.send_instance_notification("trace_approve_cc", instance, "", current_user_info, cc_user_ids);

		flow_id = instance.flow;
		approve.cc_user_ids = cc_user_ids; // 记录下本次传阅的人员ID作为hook接口中的参数
		// 如果已经配置webhook并已激活则触发
		pushManager.triggerWebhook(flow_id, instance, approve, 'cc_do', current_user_id, cc_user_ids)
		return true;
	},

	cc_read: function (approve) {
		var setObj = {};
		var ins_id = approve.instance;
		var trace_id = approve.trace;
		var instance = db.instances.findOne(ins_id, {
			fields: {
				traces: 1
			}
		});
		var current_user_id = this.userId;
		var current_trace = _.find(instance.traces, function (t) {
			return t._id == trace_id;
		})

		var index = 0;

		current_trace.approves.forEach(function (a, idx) {
			if (a.type == 'cc' && a.handler == current_user_id && !a.is_read) {
				index = idx;
			}
		});

		setObj['traces.$.approves.' + index + '.is_read'] = true;
		setObj['traces.$.approves.' + index + '.read_date'] = new Date();

		setObj.traces = traces;

		db.instances.update({
			_id: ins_id,
			'traces._id': trace_id
		}, {
			$set: setObj
		});
		return true;
	},

	cc_submit: function (ins_id, description, myApprove, ccHasEditPermission) {
		var setObj = {};

		var instance = db.instances.findOne(ins_id);
		var traces = instance.traces;
		var current_user_id = this.userId;

		var flow = uuflowManager.getFlow(instance.flow);
		var values = myApprove.values || {};

		var approve_id = myApprove._id;

		var myTrace;

		for (let tidx = 0; tidx < traces.length; tidx++) {
			const t = traces[tidx];
			if (t.approves) {
				for (let aidx = 0; aidx < t.approves.length; aidx++) {
					const a = t.approves[aidx];
					if (a.type == 'cc' && a.handler == current_user_id && a.is_finished == false) {
						var upobj = {};
						var key_str = 'traces.$.approves.' + aidx + '.';
						upobj[key_str + 'is_finished'] = true;
						upobj[key_str + 'is_read'] = true;
						upobj[key_str + 'finish_date'] = new Date();
						upobj[key_str + 'judge'] = "submitted";
						upobj[key_str + 'cost_time'] = new Date() - a.start_date;
						if (approve_id == a._id && !t.is_finished && ccHasEditPermission) {
							myTrace = t;
							var step = uuflowManager.getStep(instance, flow, t.step);
							upobj[key_str + "values"] = uuflowManager.getApproveValues(values, step["permissions"], instance.form, instance.form_version)
						}
						//设置意见，意见只添加到最后一条approve中
						if (approve_id == a._id) {
							upobj[key_str + 'description'] = description;
						}
						db.instances.update({
							_id: ins_id,
							'traces._id': t._id
						}, {
							$set: upobj
						})
					}
				}
			}

		}

		if (myApprove) {

			setObj.modified = new Date();
			setObj.modified_by = this.userId;

			if (ccHasEditPermission && myApprove && !myTrace.is_finished) {
				var ins = uuflowManager.getInstance(ins_id);
				var updated_values = uuflowManager.getUpdatedValues(ins, approve_id);
				setObj.values = updated_values;
				setObj.name = uuflowManager.getInstanceName(instance);
			}

			db.instances.update({
				_id: ins_id,
				'traces._id': myApprove.trace
			}, {
				$set: setObj,
				$pull: {
					cc_users: current_user_id
				},
				$addToSet: {
					outbox_users: {
						$each: [current_user_id, myApprove.user]
					}
				}
			});

			instance = db.instances.findOne(ins_id);

			current_user_info = db.users.findOne(current_user_id);
			//传阅提交不通知传阅者
			if (false && description && myApprove && myApprove.from_user) {
				pushManager.send_instance_notification("trace_approve_cc_submit", instance, "", current_user_info, [myApprove.from_user]);
			}

			pushManager.send_message_to_specifyUser("current_user", current_user_id);

			flow_id = instance.flow;
			// 如果已经配置webhook并已激活则触发
			pushManager.triggerWebhook(flow_id, instance, myApprove, 'cc_submit', current_user_id, []);
		}

		return true;
	},

	cc_remove: function (instanceId, approveId) {
		var setObj = {};

		var instance = db.instances.findOne(instanceId, {
			fields: {
				traces: 1,
				cc_users: 1
			}
		});
		var traces = instance.traces;
		var trace_id, remove_user_id, multi = false;

		traces.forEach(function (t) {
			if (t.approves) {
				t.approves.forEach(function (a, idx) {
					if (a._id == approveId) {
						trace_id = a.trace;
						remove_user_id = a.handler;
						setObj['traces.$.approves.' + idx + '.judge'] = 'terminated';
						setObj['traces.$.approves.' + idx + '.is_finished'] = true;
						setObj['traces.$.approves.' + idx + '.finish_date'] = new Date();
						setObj['traces.$.approves.' + idx + '.is_read'] = true;
						setObj['traces.$.approves.' + idx + '.read_date'] = new Date();
					}
				});
			}
		})

		if (!trace_id || !remove_user_id)
			return;

		var multi = 0;
		traces.forEach(function (t) {
			if (t.approves) {
				t.approves.forEach(function (a) {
					if (a.handler == remove_user_id && a.type == 'cc' && a.is_finished == false) {
						multi++;
					}
				});
			}
		})

		setObj.modified = new Date();
		setObj.modified_by = this.userId;

		if (multi > 1) {
			db.instances.update({
				_id: instanceId,
				'traces._id': trace_id
			}, {
				$set: setObj
			});
		} else {
			db.instances.update({
				_id: instanceId,
				'traces._id': trace_id
			}, {
				$set: setObj,
				$pull: {
					cc_users: remove_user_id
				}
			});
		}


		pushManager.send_message_to_specifyUser("current_user", remove_user_id);
		return true;
	},

	cc_save: function (ins_id, description, myApprove, ccHasEditPermission) {
		var setObj = {};

		var instance = db.instances.findOne(ins_id);
		var traces = instance.traces;
		var current_user_id = this.userId;

		var myTrace;

		traces.forEach(function (t) {
			if (t.approves) {
				t.approves.forEach(function (a, idx) {
					if (a.handler == current_user_id && a.type == 'cc' && a.is_finished == false) {
						var upobj = {};
						upobj['traces.$.approves.' + idx + '.judge'] = "submitted";
						upobj['traces.$.approves.' + idx + '.read_date'] = new Date();
						db.instances.update({
							_id: ins_id,
							'traces._id': t._id
						}, {
							$set: upobj
						})

					}
				});
			}
		})

		var index = 0;
		var currentStepId;

		//设置意见，意见只添加到最后一条approve中
		traces.forEach(function (t) {
			if (myApprove && t._id === myApprove.trace) {
				currentStepId = t.step;
				myTrace = t;
				if (t.approves) {
					t.approves.forEach(function (a, idx) {
						if (a._id === myApprove._id) {
							index = idx;
						}
					});
				}
			}
		});

		setObj['traces.$.approves.' + index + '.description'] = description;

		var updateObj = {};

		if (ccHasEditPermission && myApprove && !myTrace.is_finished) {

			var key_str = 'traces.$.approves.' + index + '.';

			var flow = uuflowManager.getFlow(instance.flow);

			var step = uuflowManager.getStep(instance, flow, currentStepId);

			var permissions_values = uuflowManager.getApproveValues(myApprove.values, step.permissions, instance.form, instance.form_version);

			var change_values = approveManager.getChangeValues(instance.values, permissions_values);

			setObj.values = _.extend((instance.values || {}), permissions_values);

			if (!_.isEmpty(change_values)) {
				var pushObj = {};
				pushObj[key_str + 'values_history'] = {
					values: change_values,
					create: new Date()
				}
				updateObj.$push = pushObj;
			}

			setObj.name = uuflowManager.getInstanceName(instance)
		}

		updateObj.$set = setObj;

		db.instances.update({
			_id: ins_id,
			'traces._id': myApprove.trace
		}, updateObj);

		return true;
	}
})