/*globals Y */
/**
* The Host Module is responsible for storing info for one or more hosts, and displaying them
* @module host
* @namespace Y.Pogo.Model
* @requires base,modellist,pogo-model-host
*/

/**
* The Host modellist is a convenience for storing a list of host models
* @class HostsList
* @extends Y.ModelList
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.Model').HostsList = Y.Base.create('pogo-model-hostslist', Y.ModelList, [], {
    /**
    * Store results in Y.Pogo.Model.Host model objects
    * @parameter model
    * @type Object
    * @default Y.Pogo.Model.Host
    * @private
    */
    model: Y.Pogo.Model.Host
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
