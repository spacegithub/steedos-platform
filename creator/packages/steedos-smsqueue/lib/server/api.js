var isConfigured = false;
var sendWorker = function(task, interval) {

	if (SMSQueue.debug) {
		console.log('SMSQueue: Send worker started, using interval: ' + interval);
	}

	return Meteor.setInterval(function() {
		try {
			task();
		} catch (error) {
			if (SMSQueue.debug) {
				console.log('SMSQueue: Error while sending: ' + error.message);
			}
		}
	}, interval);
};



/*
	options: {
		// Controls the sending interval
		sendInterval: Match.Optional(Number),
		// Controls the sending batch size per interval
		sendBatchSize: Match.Optional(Number),
		// Allow optional keeping notifications in collection
		keepSMS: Match.Optional(Boolean)
	}
*/
SMSQueue.Configure = function(options) {
	var self = this;
	options = _.extend({
		sendTimeout: 60000, // Timeout period for sms send
	}, options);

	// Block multiple calls
	if (isConfigured) {
		throw new Error('SMSQueue.Configure should not be called more than once!');
	}

	isConfigured = true;

	// Add debug info
	if (SMSQueue.debug) {
		console.log('SMSQueue.Configure', options);
	}

	var SMS = require('aliyun-sms-node'),
	smsSender;

	smsSender = new SMS({
		AccessKeyId: options.accessKeyId,
		AccessKeySecret: options.accessKeySecret
	});

	self.sendSMS = function(sms) {
		if (SMSQueue.debug) {
			console.log("sendSMS");
			console.log(sms);
		}

		smsSender.send(sms.sms).catch(err => {
			console.error(err)
		});
	}

	// Universal send function
	var _querySend = function(options) {

		if (self.sendSMS) {
			self.sendSMS(options);
		}

		return {
			sms: [options._id]
		};
	};

	self.serverSend = function(options) {
		options = options || {};
		return _querySend(options);
	};


	// This interval will allow only one sms to be sent at a time, it
	// will check for new sms at every `options.sendInterval`
	// (default interval is 15000 ms)
	//
	// It looks in sms collection to see if theres any pending
	// sms, if so it will try to reserve the pending sms.
	// If successfully reserved the send is started.
	//
	// If sms.query is type string, it's assumed to be a json string
	// version of the query selector. Making it able to carry `$` properties in
	// the mongo collection.
	//
	// Pr. default sms are removed from the collection after send have
	// completed. Setting `options.keepSMS` will update and keep the
	// sms eg. if needed for historical reasons.
	//
	// After the send have completed a "send" event will be emitted with a
	// status object containing sms id and the send result object.
	//
	var isSending = false;

	if (options.sendInterval !== null) {

		// This will require index since we sort sms by createdAt
		SMSQueue.collection._ensureIndex({
			createdAt: 1
		});
		SMSQueue.collection._ensureIndex({
			sent: 1
		});
		SMSQueue.collection._ensureIndex({
			sending: 1
		});


		var sendSMS = function(sms) {
			// Reserve sms
			var now = +new Date();
			var timeoutAt = now + options.sendTimeout;
			var reserved = SMSQueue.collection.update({
				_id: sms._id,
				sent: false, // xxx: need to make sure this is set on create
				sending: {
					$lt: now
				}
			}, {
				$set: {
					sending: timeoutAt,
				}
			});

			// Make sure we only handle sms reserved by this
			// instance
			if (reserved) {

				// Send the sms
				var result = SMSQueue.serverSend(sms);

				if (!options.keepSMS) {
					// Pr. Default we will remove sms
					SMSQueue.collection.remove({
						_id: sms._id
					});
				} else {

					// Update the sms
					SMSQueue.collection.update({
						_id: sms._id
					}, {
						$set: {
							// Mark as sent
							sent: true,
							// Set the sent date
							sentAt: new Date(),
							// Not being sent anymore
							sending: 0
						}
					});

				}

				// Emit the send
				self.emit('send', {
					sms: sms._id,
					result: result
				});

			} // Else could not reserve
		}; // EO sendSMS

		sendWorker(function() {

			if (isSending) {
				return;
			}
			// Set send fence
			isSending = true;

			var batchSize = options.sendBatchSize || 1;

			var now = +new Date();

			// Find sms that are not being or already sent
			var pendingSMS = SMSQueue.collection.find({
				$and: [
					// Message is not sent
					{
						sent: false
					},
					// And not being sent by other instances
					{
						sending: {
							$lt: now
						}
					}
				]
			}, {
				// Sort by created date
				sort: {
					createdAt: 1
				},
				limit: batchSize
			});

			pendingSMS.forEach(function(sms) {
				try {
					sendSMS(sms);
				} catch (error) {

					if (SMSQueue.debug) {
						console.log('SMSQueue: Could not send sms id: "' + sms._id + '", Error: ' + error.message);
					}
				}
			}); // EO forEach

			// Remove the send fence
			isSending = false;
		}, options.sendInterval || 15000); // Default every 15th sec

	} else {
		if (SMSQueue.debug) {
			console.log('SMSQueue: Send server is disabled');
		}
	}

};