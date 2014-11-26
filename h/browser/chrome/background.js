(function () {
  'use strict';

  var manifest = chrome.runtime.getManifest();
  var browserExtension = new h.HypothesisChromeExtension({
    chromeTabs: chrome.tabs,
    chromeBrowserAction: chrome.browserAction,
    sidebarResources: manifest['hypothesis_application_resources'],
    extensionURL: function (path) {
      return chrome.extension.getURL(path);
    },
    isAllowedFileSchemeAccess: function (fn) {
      return chrome.extension.isAllowedFileSchemeAccess(fn);
    },
  });

  browserExtension.listen(window);
  chrome.runtime.onInstalled.addListener(onInstalled);
  chrome.runtime.onUpdateAvailable.addListener(onUpdateAvailable);

  function onInstalled(installDetails) {
    if (installDetails.reason === 'install') {
      browserExtension.firstRun();
    }

    // We need this so that 3-rd party cookie blocking does not kill us.
    // See https://github.com/hypothesis/h/issues/634 for more info.
    // This is intended to be a temporary fix only.
    var details = {
      primaryPattern: 'https://hypothes.is/*',
      setting: 'allow'
    };
    chrome.contentSettings.cookies.set(details);
    chrome.contentSettings.images.set(details);
    chrome.contentSettings.javascript.set(details);

    browserExtension.install();
  }

  function onUpdateAvailable() {
    chrome.runtime.reload();
  }
})();
