Steedos.authRequest = function (url, options) {
    var userSession = Creator.USER_CONTEXT;
    var spaceId = userSession.spaceId;
    var authToken = userSession.authToken ? userSession.authToken : userSession.user.authToken;
    url = Steedos.absoluteUrl(url);
    try {
        var authorization = "Bearer " + spaceId + "," + authToken;
        var headers = [{
            name: 'Content-Type',
            value: 'application/json'
        }, {
            name: 'Authorization',
            value: authorization
        }];

        var defOptions = {
            type: "get",
            url: url,
            dataType: "json",
            contentType: 'application/json',
            beforeSend: function (XHR) {
                if (headers && headers.length) {
                    return headers.forEach(function (header) {
                        return XHR.setRequestHeader(header.name, header.value);
                    });
                }
            },
            success: function (data) {
                $("body").removeClass("loading");
                toastr.success(t('OK'));
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                console.error(XMLHttpRequest.responseJSON);
                $("body").removeClass("loading");
                if (XMLHttpRequest.responseJSON && XMLHttpRequest.responseJSON.error) {
                    toastr.error(t(XMLHttpRequest.responseJSON.error.replace(/:/g, '：')))
                }
                else {
                    toastr.error(XMLHttpRequest.responseJSON)
                }
            }
        }
        $.ajax(Object.assign({}, defOptions, options));
    } catch (err) {
        console.error(err);
        toastr.error(err);
        $("body").removeClass("loading");
    }
}