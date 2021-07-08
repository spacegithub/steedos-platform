JsonRoutes.add 'post', '/api/billing/recharge/notify', (req, res, next) ->
	try
		body = ""
		req.on('data', (chunk)->
			body += chunk
		)
		req.on('end', Meteor.bindEnvironment((()->
				xml2js = require('xml2js')
				parser = new xml2js.Parser({ trim:true, explicitArray:false, explicitRoot:false })
				parser.parseString(body, (err, result)->
						# 特别提醒：商户系统对于支付结果通知的内容一定要做签名验证,并校验返回的订单金额是否与商户侧的订单金额一致，防止数据泄漏导致出现“假通知”，造成资金损失
						WXPay = require('weixin-pay')
						wxpay = WXPay({
							appid: Meteor.settings.billing.appid,
							mch_id: Meteor.settings.billing.mch_id,
							partner_key: Meteor.settings.billing.partner_key #微信商户平台API密钥
						})
						sign = wxpay.sign(_.clone(result))
						attach = JSON.parse(result.attach)
						code_url_id = attach.code_url_id
						bpr = db.billing_pay_records.findOne(code_url_id)
						if bpr and bpr.total_fee is Number(result.total_fee) and sign is result.sign
							db.billing_pay_records.update({_id: code_url_id}, {$set: {paid: true}})
							billingManager.special_pay(bpr.space, bpr.modules, Number(result.total_fee), bpr.created_by, bpr.end_date, bpr.user_count)
					
				)
			), (err)->
				console.error err.stack
				console.log 'Failed to bind environment: api_billing_recharge_notify.coffee'
			)
		)
		
	catch e
		console.error e.stack

	res.writeHead(200, {'Content-Type': 'application/xml'})
	res.end('<xml><return_code><![CDATA[SUCCESS]]></return_code></xml>')

		