Meteor.methods
	setSpaceUserPassword: (space_user_id, space_id, password) ->
		if !this.userId
			throw new Meteor.Error(400, "请先登录")
		
		space = db.spaces.findOne({_id: space_id})
		isSpaceAdmin = space?.admins?.includes(this.userId)

		unless isSpaceAdmin
			throw new Meteor.Error(400, "您没有权限修改该用户密码")

		spaceUser = db.space_users.findOne({_id: space_user_id, space: space_id})
		user_id = spaceUser.user;
		userCP = db.users.findOne({_id: user_id})
		currentUser = db.users.findOne({_id: this.userId})

		if spaceUser.invite_state == "pending" or spaceUser.invite_state == "refused"
			throw new Meteor.Error(400, "该用户尚未同意加入该工作区，无法修改密码")

		Steedos.validatePassword(password)
		logout = true;
		if this.userId == user_id
			logout = false
		Accounts.setPassword(user_id, password, {logout: logout})
		changedUserInfo = db.users.findOne({_id: user_id})
		if changedUserInfo
			db.users.update({_id: user_id}, {$push: {'services.password_history': changedUserInfo.services?.password?.bcrypt}})

		# 如果用户手机号通过验证，就发短信提醒
		if userCP.mobile && userCP.mobile_verified
			lang = 'en'
			if userCP.locale is 'zh-cn'
				lang = 'zh-CN'
			SMSQueue.send
				Format: 'JSON',
				Action: 'SingleSendSms',
				ParamString: '',
				RecNum: userCP.mobile,
				SignName: '华炎办公',
				TemplateCode: 'SMS_67200967',
				msg: TAPi18n.__('sms.change_password.template', {}, lang)

