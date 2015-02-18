# -*- coding: utf-8 -*-
from __future__ import unicode_literals
import datetime

from pyramid import security
from pyramid.events import subscriber
from pyramid.settings import asbool

from horus.events import (
    NewRegistrationEvent,
    RegistrationActivatedEvent,
    PasswordResetEvent,
)

from .events import (
    LoginEvent,
    LogoutEvent,
)

from h.stats import get_client as stats


@subscriber(LoginEvent)
@subscriber(NewRegistrationEvent, autologin=True)
@subscriber(PasswordResetEvent, autologin=True)
@subscriber(RegistrationActivatedEvent)
def login(event):
    request = event.request
    user = event.user
    userid = 'acct:{}@{}'.format(user.username, request.domain)

    # Record a login event
    stats(request).get_counter('auth.local.login').increment()

    # Update the user's last login date
    user.last_login_date = datetime.datetime.utcnow()

    headers = security.remember(request, userid)
    request.response.headerlist.extend(headers)


@subscriber(LogoutEvent)
def logout(event):
    stats(event.request).get_counter('auth.local.logout').increment()


@subscriber(NewRegistrationEvent)
def new_registration(event):
    stats(event.request).get_counter('auth.local.register').increment()


@subscriber(PasswordResetEvent)
def password_reset(event):
    stats(event.request).get_counter('auth.local.reset_password').increment()


@subscriber(RegistrationActivatedEvent)
def registration_activated(event):
    stats(event.request).get_counter('auth.local.activate').increment()


class AutoLogin(object):
    """
    AutoLogin is a subscriber predicate that ensures that the marked subscriber
    will only be called if the value of the ``horus.autologin`` setting matches
    the value provided to the predicate.
    """

    def __init__(self, val, config):
        self.val = val

    def text(self):
        return 'autologin = %s' % (self.val,)

    phash = text

    def __call__(self, event):
        request = event.request
        settings = request.registry.settings
        autologin = asbool(settings.get('horus.autologin', False))
        return self.val == autologin


def includeme(config):
    config.add_subscriber_predicate('autologin', AutoLogin)
    config.scan(__name__)
