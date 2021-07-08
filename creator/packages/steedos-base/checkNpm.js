import {
	checkNpmVersions
} from 'meteor/tmeasday:check-npm-versions';
checkNpmVersions({
	"node-schedule": "^1.3.1",
	cookies: "^0.6.2",
	"xml2js": "^0.4.19",
	mkdirp: "^0.3.5",
	"url-search-params-polyfill": "^7.0.0",
}, 'steedos:base');

if (Meteor.settings && Meteor.settings.billing) {
	checkNpmVersions({
		"weixin-pay": "^1.1.7"
	}, 'steedos:base');
}