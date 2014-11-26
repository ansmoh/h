(function (h) {
  'use strict';

  /* The SidebarInjector is used to deploy and remove the Hypothesis from
   * tabs. It also deals with loading PDF documents into the PDFjs viewer
   * when applicable.
   *
   * chromeTabs - An instance of chrome.tabs.
   * options    - An options oblect with additional helper methods.
   *   isAllowedFileSchemeAccess: A function that returns true if the user
   *   can access resources over the file:// protocol. See:
   *   https://developer.chrome.com/extensions/extension#method-isAllowedFileSchemeAccess
   *   extensionURL: A function that recieves a path and returns an absolute
   *   url. See: https://developer.chrome.com/extensions/extension#method-getURL
   */
  function SidebarInjector(chromeTabs, options) {
    options = options || {};

    var isAllowedFileSchemeAccess = options.isAllowedFileSchemeAccess;
    var extensionURL = options.extensionURL;
    var resources = options.resources;

    if (typeof extensionURL !== 'function') {
      throw new TypeError('createURL must be a function');
    }

    if (typeof isAllowedFileSchemeAccess !== 'function') {
      throw new TypeError('isAllowedFileSchemeAccess must be a function');
    }

    if (!Array.isArray(resources)) {
      throw new TypeError('resources must be an array of files');
    }

    /* Injects the Hypothesis sidebar into the tab provided. The promise
     * will be rejected with an error if the injection fails. See errors.js
     * for the full list of errors.
     *
     * tab - A tab object representing the tab to insert the sidebar into.
     *
     * Returns a promise that will be resolved if the injection went well
     * otherwise it will be rejected with an error.
     */
    this.injectIntoTab = function (tab) {
      if (isFileURL(tab.url)) {
        return injectIntoLocalDocument(tab);
      } else {
        return injectIntoRemoteDocument(tab);
      }
    };

    /* Removes the Hypothesis sidebar from the tab provided. The callback
     * will be called when removal is complete. An error is passed as the
     * first argument to the callback if removal failed.
     *
     * tab - A tab object representing the tab to remove the sidebar from.
     *
     * Returns a promise that will be resolved if the removal succeeded
     * otherwise it will be rejected with an error.
     */
    this.removeFromTab = function (tab) {
      if (isPDFViewerURL(tab.url)) {
        return removeFromPDF(tab);
      } else {
        return removeFromHTML(tab);
      }
    };

    function getPDFViewerURL(url) {
      var PDF_VIEWER_URL = extensionURL('/content/web/viewer.html');
      return PDF_VIEWER_URL + '?file=' + encodeURIComponent(url);
    }

    function isPDFURL(url) {
      return url.toLowerCase().indexOf('.pdf') > 0;
    }

    function isPDFViewerURL(url) {
      return url.indexOf(getPDFViewerURL('')) === 0;
    }

    function isFileURL(url) {
      return url.indexOf("file:") === 0;
    }

    function isSupportedURL(url) {
      var SUPPORTED_PROTOCOLS = ['http:', 'https:', 'ftp:'];
      return SUPPORTED_PROTOCOLS.some(function (protocol) {
        return url.indexOf(protocol) === 0;
      });
    }

    function injectIntoLocalDocument(tab) {
      if (isPDFURL(tab.url)) {
        return injectIntoLocalPDF(tab);
      } else {
        return Promise.reject(new h.LocalFileError('Local non-PDF files are not supported'));
      }
    }

    function injectIntoRemoteDocument(tab) {
      return isPDFURL(tab.url) ? injectIntoPDF(tab) : injectIntoHTML(tab);
    }

    function injectIntoPDF(tab) {
      return new Promise(function (resolve, reject) {
        if (!isPDFViewerURL(tab.url)) {
          chromeTabs.update(tab.id, {url: getPDFViewerURL(tab.url)}, function () {
            resolve();
          });
        } else {
          resolve();
        }
      });
    }

    function injectIntoLocalPDF(tab) {
      return new Promise(function (resolve, reject) {
        isAllowedFileSchemeAccess(function (isAllowed) {
          if (isAllowed) {
            resolve(injectIntoPDF(tab));
          } else {
            reject(new h.NoFileAccessError('Local file scheme access denied'));
          }
        });
      });
    }

    function injectIntoHTML(tab) {
      return new Promise(function (resolve, reject) {
        if (!isSupportedURL(tab.url)) {
          var protocol = tab.url.split(':')[0];
          return reject(new h.RestrictedProtocolError('Cannot load Hypothesis into ' + protocol + ' pages'));
        }

        return isSidebarInjected(tab.id).then(function (isInjected) {
          if (!isInjected) {
            injectConfig(tab.id).then(function () {
              chromeTabs.executeScript(tab.id, {
                code: '(' + appendSidebarLink.toString() + ')("' + extensionURL('/public/') + '")'
              }, function () {
                loadResources(resources, {
                  script: function (src, fn) {
                    chromeTabs.executeScript(tab.id, {file: src}, function (result) {
                      if (result) {
                        fn();
                      } else {
                        fn(new Error('Failed to load script: ' + src));
                      }
                    });
                  },
                  stylesheet: function (src, fn) {
                    chromeTabs.insertCSS(tab.id, {file: src}, fn);
                  }
                });
              });
            });
          } else {
            resolve();
          }
        });
      });
    }

    function removeFromPDF(tab) {
      return new Promise(function (resolve) {
        var url = tab.url.slice(getPDFViewerURL('').length).split('#')[0];
        chromeTabs.update(tab.id, {
          url: decodeURIComponent(url)
        }, resolve);
      });
    }

    function removeFromHTML(tab) {
      return new Promise(function (resolve, reject) {
        if (!isSupportedURL(tab.url)) {
          return resolve();
        }

        return isSidebarInjected(tab.id).then(function (isInjected) {
          if (isInjected) {
            chromeTabs.executeScript(tab.id, {
              file: '/public/destroy.js'
            }, resolve);
          } else {
            resolve();
          }
        });
      });
    }

    function isSidebarInjected(tabId) {
      return new Promise(function (resolve, reject) {
        return chromeTabs.executeScript(tabId, {code: '!!window.annotator'}, function (result) {
          resolve((result && result[0] === true) || false);
        });
      });
    }

    function injectConfig(tabId) {
      return new Promise(function (resolve) {
        chromeTabs.executeScript(tabId, {file: '/public/config.js'}, resolve);
      });
    }
  }

  h.SidebarInjector = SidebarInjector;
})(window.h || (window.h = {}));
