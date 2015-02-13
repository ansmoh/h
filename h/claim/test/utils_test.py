from mock import patch, Mock
from pyramid.testing import DummyRequest
from webob.cookies import SignedSerializer


def configure(config):
    serializer = SignedSerializer('foobar', 'h.claim.secret')
    config.registry.claim_serializer = serializer


def test_generate_claim_url(config):
    configure(config)

    request = DummyRequest()
    request.route_url = Mock(return_value='<url>')

    with patch.object(request.registry.claim_serializer, 'dumps') as dumps:
        dumps.return_value = '<token>'
        from ..util import generate_claim_url
        url = generate_claim_url(request, 1)

    assert url == '<url>'
    dumps.assert_called_with({'userid': 1})
    request.route_url.assert_called_with('claim_account', token='<token>')
