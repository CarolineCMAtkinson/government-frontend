(function () {
  'use strict'

  window.GOVUK = window.GOVUK || {}
  var GOVUK = window.GOVUK

  function SetGaClientIdOnUrlInElement(options) {
    if (!options.$linkedElement || !options.attribute || !window.ga) {
      return
    }

    var linkedElement = options.$linkedElement
    var attribute = options.attribute

    window.ga(function (tracker) {
      var clientId = tracker.get('clientId')
      var attributeUrl = linkedElement.attr(attribute)
      linkedElement.attr(attribute, attributeUrl + "?_ga=" + clientId)
    })
  }

  GOVUK.SetGaClientIdOnUrlInElement = SetGaClientIdOnUrlInElement
})(window, window.GOVUK);