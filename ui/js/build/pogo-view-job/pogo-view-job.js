YUI.add('pogo-view-job', function(Y) {

/*globals Y */
/**
* The Views Module contains views for displaying data
* @module views
* @namespace Y.Pogo.View
* @requires base,view,pogo-model-hostslist,pogo-view-jobmetadata,pogo-view-jobhostdata
*/

/**
* The Job view meshes together the job metadata and job host list views
* @class Job
* @extends Y.View
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.View').Job = Y.Base.create('pogo-view-job', Y.View, [], {
    /**
    * Creates the HostList for use in the hosts view. Initializes sub-views.
    * @method initializer
    * @private
    */
    initializer: function () {
        var  model = this.get('model'),
            modelList = new Y.Pogo.Model.HostsList(),
            jobid = model.get('id');
        Y.each(model.get('hosts'), function (o, key) {
            o.jobid = jobid;
            o.host = key;
            o.duration = o.finish_time - o.start_time;
            o.job_start = model.get('start_time');
            o.job_finish = model.get('finish_time') || (new Date()).getTime() / 1000;
            o.job_duration = model.get('duration');
            modelList.add(o);
        }, this);
        

        // This view serves as a "page"-level view containing two sub-views to
        // which it delegates rendering and stitches together the resulting UI.
        this.metadataView = new Y.Pogo.View.JobMetaData({model: model});
        this.hostsView = new Y.Pogo.View.JobHostData({modelList: modelList, jobid: model.get('id')});

        // This will cause the sub-views' custom events to bubble up to here.
        this.metadataView.addTarget(this);
        this.hostsView.addTarget(this);
    },

    /**
    * This destructor is specified so this view's sub-views can be properly destroyed and cleaned up.
    * @method destructor
    * @private
    */
    destructor: function () {
        this.metadataView.destroy();
        this.hostsView.destroy();

        delete this.metadataView;
        delete this.hostsView;
    },

    template: '<h1>{jobid} for {user}</h1>',

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
        
        content.append(Y.Node.create(Y.Lang.sub(this.template, {jobid: model.get('id'), user: model.get('user')})));

        // This renders each of the two sub-views into the document fragment,
        // then sets the fragment as the contents of this view's container.
        content.append(this.metadataView.render().get('container'));
        content.append(this.hostsView.render().get('container'));
        this.get('container').setContent(content);
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


}, '@VERSION@' ,{requires:['base','view','pogo-model-hostslist','pogo-view-jobmetadata','pogo-view-jobhostdata']});
