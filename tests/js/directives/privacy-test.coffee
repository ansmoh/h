assert = chai.assert

VISIBILITY_KEY ='hypothesis.visibility'
VISIBILITY_PUBLIC = 'public'
VISIBILITY_PRIVATE = 'private'

describe 'h.directives.privacy', ->
  $window = null
  $scope = null
  $compile = null
  $injector = null
  $element = null
  $isolateScope = null

  beforeEach module('h')
  beforeEach module('h.templates')

  describe 'memory fallback', ->
    fakeAuth = null
    sandbox = null

    beforeEach module ($provide) ->
      sandbox = sinon.sandbox.create()

      fakeAuth = {
        user: 'acct:angry.joe@texas.com'
      }

      $provide.value 'auth', fakeAuth
      return

    afterEach ->
      sandbox.restore()

    describe 'has memory fallback', ->
      $window = null
      $scope2 = null

      beforeEach inject (_$compile_, _$rootScope_, _$window_) ->
        $compile = _$compile_
        $scope = _$rootScope_.$new()
        $scope2 = _$rootScope_.$new()
        $window = _$window_

        $window.localStorage = null

      it 'stores the default visibility level when it changes', ->
        $scope.permissions = {read: ['acct:user@example.com']}
        $element = $compile('<privacy ng-model="permissions">')($scope)
        $scope.$digest()
        $isolateScope = $element.isolateScope()
        $isolateScope.setLevel(name: VISIBILITY_PUBLIC)

        $scope2.permissions = {read: []}
        $element = $compile('<privacy ng-model="permissions">')($scope2)
        $scope2.$digest()

        # Roundabout way: the storage works because the directive
        # could read out the privacy level
        readPermissions = $scope2.permissions.read[0]
        assert.equal readPermissions, 'group:__world__'

  describe 'has localStorage', ->
    sandbox = null
    fakeAuth = null

    beforeEach module ($provide) ->
      sandbox = sinon.sandbox.create()

      fakeAuth = {
        user: 'acct:angry.joe@texas.com'
      }

      $provide.value 'auth', fakeAuth
      return

    afterEach ->
      sandbox.restore()

    beforeEach inject (_$compile_, _$rootScope_, _$injector_, _$window_) ->
      $compile = _$compile_
      $scope = _$rootScope_.$new()
      $injector = _$injector_
      $window = _$window_

    describe 'storage', ->
      store = null

      beforeEach ->
        store = $window.localStorage

      it 'stores the default visibility level when it changes', ->
        $scope.permissions = {read: ['acct:user@example.com']}
        $element = $compile('<privacy ng-model="permissions">')($scope)
        $scope.$digest()
        $isolateScope = $element.isolateScope()
        $isolateScope.setLevel(name: VISIBILITY_PUBLIC)

        expected = VISIBILITY_PUBLIC
        stored = store.getItem VISIBILITY_KEY
        assert.equal stored, expected

    describe 'setting permissions', ->
      store = null
      modelCtrl = null

      beforeEach ->
        store = $window.localStorage

      describe 'when no setting is stored', ->
        beforeEach ->
          store.removeItem VISIBILITY_KEY

        it 'defaults to public', ->
          $scope.permissions = {read: []}
          $element = $compile('<privacy ng-model="permissions">')($scope)
          $scope.$digest()
          $isolateScope = $element.isolateScope()
          assert.equal $isolateScope.level.name, VISIBILITY_PUBLIC

      describe 'when permissions.read is empty', ->
        beforeEach ->
          store.setItem VISIBILITY_KEY, VISIBILITY_PUBLIC

          $scope.permissions = {read: []}
          $element = $compile('<privacy ng-model="permissions">')($scope)
          $scope.$digest()
          $isolateScope = $element.isolateScope()

        it 'sets the initial permissions based on the stored privacy level', ->
          assert.equal $isolateScope.level.name, VISIBILITY_PUBLIC

        it 'does not alter the level on subsequent renderings', ->
          modelCtrl = $element.controller('ngModel')
          store.setItem VISIBILITY_KEY, VISIBILITY_PRIVATE
          $scope.permissions.read = ['acct:user@example.com']
          $scope.$digest()
          assert.equal $isolateScope.level.name, VISIBILITY_PUBLIC

      describe 'when permissions.read is filled', ->
        it 'does not alter the level', ->
          store.setItem VISIBILITY_KEY, VISIBILITY_PRIVATE

          $scope.permissions = {read: ['group:__world__']}
          $element = $compile('<privacy ng-model="permissions">')($scope)
          $scope.$digest()
          $isolateScope = $element.isolateScope()
          assert.equal($isolateScope.level.name, VISIBILITY_PUBLIC)

      describe 'user attribute', ->
        beforeEach ->
          $scope.permissions = {read: []}

        it 'fills the permissions fields with the auth.user name', ->
          store.setItem VISIBILITY_KEY, VISIBILITY_PRIVATE
          $element = $compile('<privacy ng-model="permissions">')($scope)
          $scope.$digest()

          readPermissions = $scope.permissions.read[0]
          updatePermissions = $scope.permissions.update[0]
          deletePermissions = $scope.permissions.delete[0]
          adminPermissions = $scope.permissions.admin[0]
          assert.equal readPermissions, fakeAuth.user
          assert.equal updatePermissions, fakeAuth.user
          assert.equal deletePermissions, fakeAuth.user
          assert.equal adminPermissions, fakeAuth.user

        it 'puts group_world into the read permissions for public visibility', ->
          store.setItem VISIBILITY_KEY, VISIBILITY_PUBLIC
          $element = $compile('<privacy ng-model="permissions">')($scope)
          $scope.$digest()

          readPermissions = $scope.permissions.read[0]
          updatePermissions = $scope.permissions.update[0]
          deletePermissions = $scope.permissions.delete[0]
          adminPermissions = $scope.permissions.admin[0]
          assert.equal readPermissions, 'group:__world__'
          assert.equal updatePermissions, fakeAuth.user
          assert.equal deletePermissions, fakeAuth.user
          assert.equal adminPermissions, fakeAuth.user
