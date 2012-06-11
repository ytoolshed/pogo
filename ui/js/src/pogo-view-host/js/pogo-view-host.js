/*globals Y */
/**
* The Views Module contains views for displaying data
* @module views
* @namespace Y.Pogo.View
* @requires base,view,pogo-view-jobmetadata,pogo-view-hostlog
*/

/**
* The Job view meshes together the job metadata and job host list views
* @class Host
* @extends Y.View
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.View').Host = Y.Base.create('pogo-view-host', Y.View, [], {
    /**
    * Creates the HostList for use in the hosts view. Initializes sub-views.
    * @method initializer
    * @private
    */
    initializer: function () {
        var model = this.get('model'), host, hostname = this.get('host');
        
        // This view serves as a "page"-level view containing two sub-views to
        // which it delegates rendering and stitches together the resulting UI.
        this.metadataView = new Y.Pogo.View.JobMetaData({model: model});
        this.logView = new Y.Pogo.View.HostLog();

        host = model.get('hosts')[hostname] || {log: ''};
        this.logView.set('logURL', host.log);
        this.render();

        // This will cause the sub-views' custom events to bubble up to here.
        this.metadataView.addTarget(this);
        this.logView.addTarget(this);
    },

    /**
    * This destructor is specified so this view's sub-views can be properly destroyed and cleaned up.
    * @method destructor
    * @private
    */
    destructor: function () {
        this.metadataView.destroy();
        this.logView.destroy();

        delete this.metadataView;
        delete this.logView;
    },
    
    template: '<h2>{host} for {user} via {jobid}</h2>',

    /**
    * Renders each of the sub-views to this view's container
    * @method render
    * @return {Object} Reference to this view
    */
    render: function () {
        // A document fragment is created to hold the resulting HTML created
        // from rendering the two sub-views.
        var content = Y.one(Y.config.doc.createDocumentFragment()),
            model = this.get('model');

        content.append(Y.Node.create(Y.Lang.sub(this.template, {host: this.get('host'), jobid: model.get('id'), user: model.get('user')})));
        
        // This renders each of the two sub-views into the document fragment,
        // then sets the fragment as the contents of this view's container.
        content.append(this.metadataView.render().get('container'));
        content.append(this.logView.render().get('container'));
        this.get('container').setContent(content);
        return this;
    }
}, {
    ATTRS: {
        host: {
            value: ''
        }
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
