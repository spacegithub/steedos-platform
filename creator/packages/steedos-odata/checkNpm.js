// fix warning: xxx not installed
require("basic-auth/package.json");

import { checkNpmVersions } from 'meteor/tmeasday:check-npm-versions';
checkNpmVersions({
	'basic-auth': '^2.0.1',
	'odata-v4-service-metadata': "^0.1.6",
	"odata-v4-service-document": "^0.0.3",
	cookies: "^0.6.1",
}, 'steedos:odata');
