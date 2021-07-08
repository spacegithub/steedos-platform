Meteor.startup ()->
    rootURL = Meteor.absoluteUrl()
    if !Meteor.settings.public.webservices
        Meteor.settings.public.webservices = {
            "creator": {
                "url": rootURL
            }
        }

    if !Meteor.settings.public.webservices.creator
        Meteor.settings.public.webservices.creator = {
            "url": rootURL
        }

    if !Meteor.settings.public.webservices.creator.url
        Meteor.settings.public.webservices.creator.url = rootURL