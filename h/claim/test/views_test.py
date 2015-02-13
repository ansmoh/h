import deform
from mock import patch, Mock
from pytest import raises
from pyramid.testing import DummyRequest
from webob.cookies import SignedSerializer
from pyramid.httpexceptions import HTTPFound
from horus.interfaces import IResetPasswordForm
from horus.interfaces import IResetPasswordSchema
from h.accounts.models import User


def configure(config):
    serializer = SignedSerializer('foobar', 'h.claim.secret')
    config.registry.claim_serializer = serializer
    config.registry.registerUtility(Mock(), IResetPasswordForm)
    config.registry.registerUtility(Mock(), IResetPasswordSchema)


def _claim_account_request():
    request = DummyRequest()
    request.user = None
    request.route_url = Mock(return_value='<url>')

    token = request.registry.claim_serializer.dumps({'userid': 1})
    request.matchdict['token'] = token

    return request


def _update_account_request(post=None):
    post = post or {'password': 'safeashouses'}
    request = DummyRequest(post=post)
    request.user = None
    request.route_url = Mock(return_value='<url>')

    token = request.registry.claim_serializer.dumps({'userid': 1})
    request.matchdict['token'] = token
    return request


def _fake_user():
    return User()


def test_claim_account_returns_form(config):
    configure(config)
    request = _claim_account_request()

    with patch('h.accounts.models.User.get_by_id') as mock_get_by_id:
        mock_get_by_id.return_value = _fake_user()

        from ..views import claim_account
        ctx = claim_account(request)
        assert 'form' in ctx


def test_claim_account_when_signed_in(config):
    configure(config)
    request = _claim_account_request()
    request.user = 'billy'

    from ..views import claim_account

    with raises(HTTPFound) as execinfo:
        claim_account(request)

    assert execinfo.value.location == '<url>'
    assert request.route_url.called_with('stream')


def test_claim_account_with_invalid_token(config):
    configure(config)
    request = _claim_account_request()
    request.matchdict['token'] = 'foobar'

    from ..views import claim_account

    with raises(ValueError) as execinfo:
        claim_account(request)

    assert str(execinfo.value) == 'Invalid signature'


def test_claim_account_when_already_registered(config):
    configure(config)
    request = _claim_account_request()

    with patch('h.accounts.models.User.get_by_id') as mock_get_by_id:
        user = _fake_user()
        user.password = '<password>'
        mock_get_by_id.return_value = user

        from ..views import claim_account
        with raises(HTTPFound) as execinfo:
            claim_account(request)

    assert execinfo.value.location == '<url>'
    request.route_url.assert_called_with('stream')


def xtest_claim_account_already_registered_message(config):
    configure(config)
    request = _claim_account_request()

    with patch('h.accounts.models.User.get_by_id') as mock_get_by_id:
        with patch('horus.lib.FlashMessage') as mock_flash:
            user = _fake_user()
            user.password = '<password>'
            mock_get_by_id.return_value = user

            from ..views import claim_account
            with raises(HTTPFound):
                claim_account(request)

    msg = 'This account has already been claimed'
    mock_flash.assert_called_with(request, msg, kind='error')


def test_update_account_db(config):
    configure(config)
    request = _update_account_request()

    with patch('h.accounts.models.User.get_by_id') as mock_get_by_id:
        user = _fake_user()
        mock_get_by_id.return_value = user

        from ..views import update_account
        update_account(request)
        assert user.password is not None


def test_update_account_response(config):
    configure(config)
    request = _update_account_request()

    with patch('h.accounts.models.User.get_by_id') as mock_get_by_id:
        user = _fake_user()
        mock_get_by_id.return_value = user

        from ..views import update_account
        res = update_account(request)
        assert isinstance(res, HTTPFound)
        assert res.location == '<url>'
        request.route_url.assert_called_with('stream')


def test_update_account_validation_error(config):
    def validation_error(arg):
        raise deform.ValidationFailure(Mock(), {}, Mock())

    configure(config)
    f = Mock()
    f.validate = Mock(side_effect=validation_error)
    config.registry.registerUtility(Mock(return_value=f), IResetPasswordForm)

    request = _update_account_request({'password': 'a'})

    with patch('h.accounts.models.User.get_by_id') as mock_get_by_id:
        user = _fake_user()
        mock_get_by_id.return_value = user

        from ..views import update_account
        res = update_account(request)
        assert 'form' in res


def test_update_account_when_signed_in(config):
    configure(config)
    request = _update_account_request()
    request.user = 'billy'

    from ..views import update_account

    with raises(HTTPFound) as execinfo:
        update_account(request)

    assert execinfo.value.location == '<url>'
    assert request.route_url.called_with('stream')


def test_update_account_with_invalid_token(config):
    configure(config)
    request = _update_account_request()
    request.matchdict['token'] = 'foobar'

    from ..views import update_account

    with raises(ValueError) as execinfo:
        update_account(request)

    assert str(execinfo.value) == 'Invalid signature'


def test_update_account_when_already_registered(config):
    configure(config)
    request = _update_account_request()

    with patch('h.accounts.models.User.get_by_id') as mock_get_by_id:
        user = _fake_user()
        user.password = '<password>'
        mock_get_by_id.return_value = user

        from ..views import update_account
        with raises(HTTPFound) as execinfo:
            update_account(request)

    assert execinfo.value.location == '<url>'
    request.route_url.assert_called_with('stream')
