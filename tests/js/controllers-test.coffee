assert = chai.assert
sinon.assert.expose assert, prefix: null

fakeStore =
  SearchResource:
    get: sinon.spy()


describe 'h', ->
  $scope = null
  fakeAuth = null
  fakeIdentity = null
  fakeLocation = null
  fakeParams = null
  fakeStreamer = null
  sandbox = null

  beforeEach module('h')

  beforeEach module ($provide) ->
    sandbox = sinon.sandbox.create()

    fakeAnnotator = {
      plugins: {
        Auth: {withToken: sandbox.spy()}
      }
      options: {}
      socialView: {name: 'none'}
      addPlugin: sandbox.spy()
    }

    fakeAuth = {
      user: null
    }

    fakeIdentity = {
      watch: sandbox.spy()
      request: sandbox.spy()
    }

    fakeLocation = {
      search: sandbox.stub().returns({})
    }
    fakeParams = {id: 'test'}
    fakeStreamer = {
      open: sandbox.spy()
      close: sandbox.spy()
      send: sandbox.spy()
    }

    fakeThreading =
      idTable:
        myId: "local annotation"

    $provide.value 'identity', fakeIdentity
    $provide.value 'streamer', fakeStreamer
    $provide.value '$location', fakeLocation
    $provide.value '$routeParams', fakeParams
    $provide.value '$threading', fakeThreading
    return

  afterEach ->
    sandbox.restore()

  describe 'AppController', ->
    createController = null

    beforeEach inject ($controller, $rootScope) ->
      $scope = $rootScope.$new()

      createController = ->
        $controller('AppController', {$scope: $scope})

    it 'does not show login form for logged in users', ->
      createController()
      assert.isFalse($scope.dialog.visible)

    describe 'applyUpdate', ->

      it 'fails', ->
        console.log "While testing, streamer is:", fakeStreamer
        fakeStreamer.onmessage "asd"
        assert false

  describe 'AnnotationViewerController', ->
    annotationViewer = null

    beforeEach inject ($controller, $rootScope) ->
      $scope = $rootScope.$new()
      $scope.search = {}
      annotationViewer = $controller 'AnnotationViewerController',
        $scope: $scope
        store: fakeStore

    it 'sets the isEmbedded property to false', ->
      assert.isFalse($scope.isEmbedded)

describe 'AnnotationUIController', ->
  $scope = null
  $rootScope = null
  annotationUI = null

  beforeEach module('h')
  beforeEach inject ($controller, _$rootScope_) ->
    $rootScope = _$rootScope_
    $scope = $rootScope.$new()
    $scope.search = {}
    annotationUI =
      tool: 'comment'
      selectedAnnotationMap: null
      focusedAnnotationsMap: null
      removeSelectedAnnotation: sandbox.stub()

    $controller 'AnnotationUIController', {$scope, annotationUI}

  it 'updates the view when the selection changes', ->
    annotationUI.selectedAnnotationMap = {1: true, 2: true}
    $rootScope.$digest()
    assert.deepEqual($scope.selectedAnnotations, {1: true, 2: true})

  it 'updates the selection counter when the selection changes', ->
    annotationUI.selectedAnnotationMap = {1: true, 2: true}
    $rootScope.$digest()
    assert.deepEqual($scope.selectedAnnotationsCount, 2)

  it 'clears the selection when no annotations are selected', ->
    annotationUI.selectedAnnotationMap = {}
    $rootScope.$digest()
    assert.deepEqual($scope.selectedAnnotations, null)
    assert.deepEqual($scope.selectedAnnotationsCount, 0)

  it 'updates the focused annotations when the focus map changes', ->
    annotationUI.focusedAnnotationMap = {1: true, 2: true}
    $rootScope.$digest()
    assert.deepEqual($scope.focusedAnnotations, {1: true, 2: true})

  describe 'on annotationDeleted', ->
    it 'removes the deleted annotation from the selection', ->
      $rootScope.$emit('annotationDeleted', {id: 1})
      assert.calledWith(annotationUI.removeSelectedAnnotation, {id: 1})
