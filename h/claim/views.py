import deform
from pyramid.view import view_config
from horus.lib import FlashMessage
from horus.interfaces import IResetPasswordForm
from horus.interfaces import IResetPasswordSchema
from pyramid.httpexceptions import HTTPFound
from h.accounts.models import User
from h.accounts.events import LoginEvent


@view_config(
    route_name='claim_account',
    request_method='GET',
    renderer='h:claim/templates/claim_account.html')
def claim_account(request):
    _check_signed_in(request, request.user)
    _user_for_token(request, request.matchdict.get('token', None))

    form = _form_for_update_account(request)
    return {'form': form}


@view_config(
    route_name='claim_account',
    request_method='POST',
    renderer='h:claim/templates/claim_account.html')
def update_account(request):
    _check_signed_in(request, request.user)
    user = _user_for_token(request, request.matchdict.get('token', None))

    form = _form_for_update_account(request)
    data = request.POST

    print form
    try:
        form.validate(data.items())
    except deform.ValidationFailure:
        return {'form': form}

    user.password = data['password']

    msg = 'Your account has been successfully claimed'
    FlashMessage(request, msg, kind='success')

    request.registry.notify(LoginEvent(request, user))
    return HTTPFound(location=request.route_url('stream'))


def includeme(config):
    config.add_route('claim_account', '/claim_account/{token}')
    config.scan(__name__)


def _user_for_token(request, token):
    payload = request.registry.claim_serializer.loads(token)
    user = User.get_by_id(request, payload['userid'])
    if not user or user.password:
        msg = 'This account has already been claimed'
        FlashMessage(request, msg, kind='error')
        raise HTTPFound(location=request.route_url('stream'))
    return user


def _form_for_update_account(request):
    schema = request.registry.getUtility(IResetPasswordSchema)
    schema = schema().bind(request=request)

    form = request.registry.getUtility(IResetPasswordForm)
    return form(schema, action=request.url)


def _check_signed_in(request, user):
    if user:
        msg = 'You are already signed in, please logout to claim an account'
        FlashMessage(request, msg, kind='error')
        raise HTTPFound(location=request.route_url('stream'))
