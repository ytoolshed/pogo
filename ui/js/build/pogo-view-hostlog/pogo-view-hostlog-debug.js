YUI.add('pogo-view-hostlog', function(Y) {

/*globals Y */
/**
* The Views Module contains views for displaying data
* @module views
* @namespace Y.Pogo.View
* @requires base,view,datatable,pogo-formatters
*/

/**
* Displays host log information
* @class HostLog
* @extends Y.View
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.View').HostLog = new Y.Base.create('pogo-view-hostlog', Y.View, [], {
    /**
    * Setup model event
    * @method initializer
    * @private
    */
    initializer: function () {
        this.after('logURLChange', this.render, this);
    },

    /**
    * The html template for the view (not including the datatable)
    * @property template
    * @type string
    * @protected
    */
    template: '<h2>Log</h2><div class="log"><iframe class="logIframe" src="{log}"></iframe></div>',

    /**
    * Renders the view
    * @method render
    * @return {Object} A reference to this view
    */
    render: function () {
        var container = this.get('container');
            
        container.setContent(Y.Lang.sub(this.template, {
            log: this.get('logURL') || "about:blank"
        }));
        return this;
    }
}, {
    ATTRS: {
        /**
         * logURL
         * @attribute logURL
         * @type String
         * @default 'about:blank'
         */
        logURL: {
            value: 'about:blank'
        }
    }
});


}, '@VERSION@' ,{requires:['base','view']});
