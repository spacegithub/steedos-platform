Package.describe({
	name: 'steedos:object-database',
	version: '0.0.2',
	summary: 'Steedos Creator',
	git: '',
	documentation: null
});

Package.onUse(function(api) {
	api.versionsFrom('1.0');
	api.use('ecmascript');
	api.use('reactive-var@1.0.10');
	api.use('reactive-dict@1.1.8');
	api.use('coffeescript@1.11.1_4');
	api.use('random@1.0.10');
	api.use('ddp@1.2.5');
	api.use('check@1.2.3');
	api.use('ddp-rate-limiter@1.0.5');
	api.use('underscore@1.0.10');
	api.use('tracker@1.1.0');
	api.use('session@1.1.6');
	api.use('simple:json-routes@2.1.0');
	api.use('nimble:restivus@0.8.7');
	api.use('aldeed:simple-schema@1.3.3');
	api.use('aldeed:schema-index@1.1.0');
	api.use('aldeed:collection2@2.5.0');
	api.use('aldeed:tabular@1.6.1');
	api.use('matb33:collection-hooks@0.8.1');
	api.use('meteorhacks:subs-manager@1.6.4');
	api.use('universe:i18n@1.20.0');
	api.use('steedos:objects@0.0.11');

	// api.addFiles('models/object.coffee');
	// api.addFiles('models/object_fields.coffee');
	// api.addFiles('models/object_triggers.coffee');
	// api.addFiles('models/object_actions.coffee');

	// api.addFiles('server/routes/api_creator_apps.coffee', 'server');
	api.addFiles('server/routes/api_creator_objects.coffee', 'server');
	//
	// api.addFiles('server/objects_observe.coffee', 'server');
	// // api.addFiles('server/publications/apps.coffee', 'server');
	api.addFiles('server/publications/objects.coffee', 'server');
	api.addFiles('server/publications/object_layouts.coffee', 'server');
	api.addFiles('client/subscribe.coffee', 'client');

});
