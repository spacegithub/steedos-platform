Package.describe({
	name: 'steedos:oauth2-server',
	version: '0.0.7',
	summary: 'Add oauth2 server support to your application.'
});

Npm.depends({
	'cookies': "0.6.1",
	"express": "4.13.4",
	"body-parser": "1.14.2",
	"oauth2-server": "2.4.1",
	"unpipe": "1.0.0"
});

Package.onUse(function(api) {
	api.versionsFrom('1.0');
	api.use('coffeescript');
	api.use('random');
	api.use('blaze@2.1.9');
	api.use('templating@1.2.15');
	api.use('flemay:less-autoprefixer@1.2.0');
	api.use('kadira:blaze-layout@2.3.0');
	api.use('kadira:flow-router@2.10.1');
	
	api.use('webapp', 'server');
	api.use('check', 'server');
	api.use('meteorhacks:async@1.0.0', 'server');
	api.use('simple:json-routes@2.1.0', 'server');

	api.use('meteorhacks:subs-manager@1.6.4');

	
	api.use('http');

	api.use('steedos:base@0.0.72');
	api.use('universe:i18n@1.13.0');
	// api.addFiles('lib/random.coffee', ['client', 'server']);

	api.addFiles('lib/common.js', ['client', 'server']);
	api.addFiles('lib/meteor-model.js', 'server');
	api.addFiles('lib/server.js', 'server');
	api.addFiles('lib/client.js', 'client');

	api.addFiles('client/oauth2authorize.html', 'client');
	api.addFiles('client/oauth2authorize.less', 'client');
	api.addFiles('client/oauth2authorize.coffee', 'client');
	
	api.addFiles('client/router.coffee', 'client');

	api.addFiles('client/subscribe.coffee');
	
	api.addFiles('server/rest.coffee', 'server');
	api.addFiles('server/publications/oauth2clients.coffee', 'server');
	api.addFiles('server/methods/oauth2authcodes.coffee', 'server');
	
	api.export('oAuth2Server', ['client', 'server']);

	api.export('Random', ['client', 'server']);
	
});

Package.onTest(function(api) {

});
