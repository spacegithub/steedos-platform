import {
	checkNpmVersions
} from 'meteor/tmeasday:check-npm-versions';
checkNpmVersions({
	busboy: "^0.2.13",
	mkdirp: "^0.3.5",
	"xml2js": "^0.4.19",
	"node-xlsx": "^0.12.0"
}, 'steedos:creator');

if (Meteor.settings && Meteor.settings.cfs && Meteor.settings.cfs.aliyun) {
	checkNpmVersions({
		"aliyun-sdk": "^1.11.12"
	}, 'steedos:creator');
}