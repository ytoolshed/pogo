YUI.add('pogo-view-dashboard', function(Y) {

/*globals Y */
/**
* The Views Module contains views for displaying data
* @module views
* @namespace Y.Pogo.View
* @requires base,pogo-view-multidatatable
*/

/**
* The Dashboard View is a means to allow customization of the dashboard beyond the defaults in MultiDatatable.
* @class Dashboard
* @extends Y.Pogo.View.MutiDatatable
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.View').Dashboard = new Y.Base.create('pogo-view-dashboard', Y.Pogo.View.MultiDatatable, []);


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


}, '@VERSION@' ,{requires:['base','pogo-view-multidatatable']});
