AUTH_SESSION_ACTIONS = [
  'login'
  'logout'
  'register'
  'forgot_password'
  'reset_password'
  'activate_account'
  'edit_profile'
  'disable_user'
]


class AuthAppController
  this.$inject = ['$location', '$scope', '$timeout', '$window', 'session']
  constructor:   ( $location,   $scope,   $timeout,   $window,   session ) ->
    onlogin = ->
      $window.location.href = '/stream'

    $scope.account = {}
    $scope.model = {}

    $scope.account.tab = $location.path().split('/')[1]

    $scope.$on 'auth', (event, err, data) ->
      if data?.userid
        $timeout onlogin, 1000

    $scope.$watch 'account.tab', (tab, old) ->
      unless tab is old then $location.path("/#{tab}")

    # TODO: We should be calling identity.beginProvisioning() here in order to
    # move toward become a federated BrowserID provider.
    session.load (data) ->
      if data.userid then onlogin()


class AuthPageController
  this.$inject = ['$routeParams', '$scope']
  constructor:   ( $routeParams,   $scope ) ->
    $scope.model.code = $routeParams.code
    $scope.hasActivationCode = !!$routeParams.code


configure = [
  '$httpProvider', '$locationProvider', '$routeProvider',
  'identityProvider', 'sessionProvider'
  (
   $httpProvider,   $locationProvider,   $routeProvider,
   identityProvider,   sessionProvider
  ) ->
    # Pending authentication check
    authCheck = null

    # Use the Pyramid XSRF header name
    $httpProvider.defaults.xsrfHeaderName = 'X-CSRF-Token'

    $locationProvider.html5Mode(true)

    routeOptions =
      controller: 'AuthPageController'
      templateUrl: 'auth.html'

    $routeProvider.when('/login', routeOptions)
    $routeProvider.when('/register', routeOptions)
    $routeProvider.when('/forgot_password', routeOptions)
    $routeProvider.when('/reset_password/:code?', routeOptions)
    $routeProvider.when('/activate_account/:code?', routeOptions)
    $routeProvider.when('/activate_account', routeOptions)

    identityProvider.checkAuthentication = [
      '$q', 'session',
      ($q,   session) ->
        (authCheck = $q.defer()).promise.then do ->
          session.load().$promise.then (data) ->
            if data.userid then authCheck.resolve data.csrf
            else authCheck.reject 'no session'
          , -> authCheck.reject 'request failure'
    ]

    identityProvider.forgetAuthentication = [
      '$q', 'flash', 'session',
      ($q,   flash,   session) ->
        session.logout({}).$promise
        .then ->
          authCheck = $q.defer()
          authCheck.reject 'no session'
          return null
        .catch (err) ->
          flash 'error', 'Sign out failed!'
          throw err
    ]

    identityProvider.requestAuthentication = [
      '$q', '$rootScope',
      ($q,   $rootScope) ->
        authCheck.promise.catch ->
          (authRequest = $q.defer()).promise.finally do ->
            $rootScope.$on 'auth', (event, err, data) ->
              if err then authRequest.reject err
              else authRequest.resolve data.csrf
    ]

    sessionProvider.actions.load =
      method: 'GET'
      withCredentials: true

    sessionProvider.actions.profile =
      method: 'GET'
      params:
        __formid__: 'profile'
      withCredentials: true

    for action in AUTH_SESSION_ACTIONS
      sessionProvider.actions[action] =
        method: 'POST'
        params:
          __formid__: action
        withCredentials: true
]


angular.module('h')
.config(configure)
.controller('AuthAppController', AuthAppController)
.controller('AuthPageController', AuthPageController)
