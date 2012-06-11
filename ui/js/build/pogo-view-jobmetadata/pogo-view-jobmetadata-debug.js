YUI.add('pogo-view-jobmetadata', function(Y) {

/*globals Y */
/**
* The Views Module contains views for displaying data
* @module views
* @namespace Y.Pogo.View
* @requires base,view
*/

/**
* The Job MetaData view displays job metadata
* @class JobMetaData
* @extends Y.View
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.View').JobMetaData = new Y.Base.create('pogo-view-jobmetadata', Y.View, [], {
    /**
    * Setup events around model changes
    * @method initializer
    * @private
    */
    initializer: function () {
        var model = this.get('model');
        model.after('change', this.render, this);
        model.after('load', this.render, this);
        model.after('destroy', this.destroy, this);
    },

    /**
    * Provide a button to halt a job
    * @property buttonTemplate
    * @type String
    * @private
    */
    buttonTemplate: '<input type="button" class="primary haltButton" value="Halt this Job">',

    /**
    * Main template for the metadata
    * @property table
    * @type String
    * @private
    */
    table: '<div><h3>Command</h3><code class="prettyprint">{command}</code></div>' +
            '<div><h3>Invoked As</h3><code class="prettyprint">{invoked_as}</code></div>' +
            '<div class="yui3-g">' + 
            '<div class="yui3-u-1-3"><h4>Request Host</h4><span class="value">{requesthost}</span></div>' +
            '<div class="yui3-u-1-12"><h4>Retry</h4><span class="value">{retry}</span></div>' +
            '<div class="yui3-u-1-12"><h4>Timeout</h4><span class="value">{timeout}</span></div>' +
            '<div class="yui3-u-1-6"><h4>Start Time</h4><span class="value">{start_time}</span></div>' +
            '<div class="yui3-u-1-6"><h4>End Time</h4><span class="value">{finish_time}</span></div>' +
            '<div class="yui3-u-1-6"><h4>State</h4><span class="value">{state}</span></div>' +
            '</div>',

    /**
    * Main template for the page
    * @property template
    * @type String
    * @private
    */
    template: '{buttonTemplate}<h2>Metadata</h2><div class="metadata">{table}</div>',

    /**
    * Renders the view
    * @method render
    * @return {Object} A reference to this view
    */
    render: function () {
        var div, container = this.get('container'),
            model = this.get('model'),
            modelData = model.toJSON(),
            buttonTemplate = '';
        
        modelData.start_time = Y.Pogo.Formatters.timeFormatter({value: modelData.start_time});
        modelData.finish_time = Y.Pogo.Formatters.timeFormatter({value: modelData.finish_time});
        
        //determine if the button should display
        if (Y.Array.indexOf(['ready', 'waiting', 'running', 'gathering'], modelData.state) > -1) {
            buttonTemplate = this.buttonTemplate;
        }

        container.setContent(Y.Lang.sub(this.template, {
            jobid: model.get('id'),
            user: model.get('user'),
            buttonTemplate: buttonTemplate,
            table: Y.Lang.sub(this.table, modelData)
        }));

        return this;
    }
});


/**
 * Copyright (c) 2010-2012 Yahoo! Inc. All rights reserved.
 *
 *     Licensed under the Apache License, Version 2.0 (the "License"); you
 * may not use this file except in compliance with the License.  You may
 * obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * imitations under the License.
 */


}, '@VERSION@' ,{requires:['base','view']});
