def generate_claim_token(request, user_id):
    return request.registry.claim_serializer.dumps({'user_id': user_id})


def generate_claim_url(request, user_id):
    ''' Generates a url that a user can visit to claim their account. '''
    token = generate_claim_token(request, user_id)
    return request.route_url('claim_account', token=token)


def includeme(config):
    pass
